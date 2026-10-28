{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;

  # each job's database copies land here before its snapshot
  dumpDirectory = "/var/backup";
  dumpJobs = lib.filterAttrs (_: job: job.sqlite != { }) config.services.restic.backups;

  # root prepares each directory and clears the previous copy, then setpriv drops to the owner,
  # so sqlite never leaves root-owned wal or shm files and no-new-privs keeps the child there
  dumpScript =
    name: job:
    lib.concatStrings (
      lib.mapAttrsToList (
        db: sqlite:
        let
          group = config.users.users.${sqlite.user}.group;
          directory = "${dumpDirectory}/${name}/sqlite/${db}";
        in
        ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 -o ${sqlite.user} -g ${group} ${directory}
          ${lib.getExe' pkgs.coreutils "rm"} -f ${directory}/${db}.db
          ${lib.getExe' pkgs.util-linux "setpriv"} --reuid=${sqlite.user} --regid=${group} --init-groups --no-new-privs --reset-env -- \
            ${lib.getExe' pkgs.sqlite "sqlite3"} -readonly -cmd ".timeout 30000" ${sqlite.path} ".backup ${directory}/${db}.db"
        ''
      ) job.sqlite
    );
in
{
  options.services.restic.backups = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options.sqlite = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "SQLite database file.";
                  };
                  user = lib.mkOption {
                    type = lib.types.str;
                    description = "Owner of the database. The copy runs as this user.";
                  };
                };
              }
            );
            default = { };
            description = "Databases copied through the SQLite online backup API to ${dumpDirectory}/<job>/sqlite/<name>/<name>.db before the snapshot.";
          };

          config.paths = lib.optional (config.sqlite != { }) "${dumpDirectory}/${name}";
        }
      )
    );
  };

  config = {
    sops.secrets."backup/b2-key-id" = { };
    sops.secrets."backup/b2-application-key" = { };
    sops.secrets."backup/restic-password" = { };
    sops.secrets."backup/healthchecks-ping-url" = { };

    sops.templates."restic-b2.env".content = ''
      AWS_ACCESS_KEY_ID=${placeholder."backup/b2-key-id"}
      AWS_SECRET_ACCESS_KEY=${placeholder."backup/b2-application-key"}
    '';

    services.restic.backups.b2 = {
      repository = "s3:https://s3.us-east-005.backblazeb2.com/lucas-backup-s3/${config.networking.hostName}";
      passwordFile = secrets."backup/restic-password".path;
      environmentFile = config.sops.templates."restic-b2.env".path;
      initialize = true;
      paths = [ "/srv" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      # the bucket keeps pruned files for 30 more days
      # one group per host, or each past set of paths keeps its own snapshots forever
      pruneOpts = [
        "--group-by host"
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      runCheck = true;
      checkOpts = [ "--read-data-subset=1%" ];
    };

    systemd.services = lib.mkMerge [
      {
        restic-backups-b2.serviceConfig = {
          Nice = 19;
          IOSchedulingClass = "idle";
          # healthchecks.io alerts on a failure ping or when a day passes without a success ping
          ExecStopPost = [
            (pkgs.writeShellScript "restic-backups-b2-healthcheck" ''
              url=$(cat ${secrets."backup/healthchecks-ping-url".path})
              [ "$SERVICE_RESULT" = success ] || url="$url/fail"
              ${lib.getExe pkgs.curl} -fsS -m 10 --retry 5 -o /dev/null "$url"
            '')
          ];
        };
      }
      # copies run after restic reaches the repository, and a failed copy fails the snapshot
      (lib.mapAttrs' (
        name: job:
        lib.nameValuePair "restic-backups-${name}" { preStart = lib.mkAfter (dumpScript name job); }
      ) dumpJobs)
    ];

    assertions = lib.concatLists (
      lib.mapAttrsToList (
        name: job:
        lib.mapAttrsToList (db: sqlite: {
          assertion = config.users.users ? ${sqlite.user};
          message = "services.restic.backups.${name}.sqlite.${db} runs as ${sqlite.user}, which is not a user on this host";
        }) job.sqlite
      ) dumpJobs
    );
  };
}
