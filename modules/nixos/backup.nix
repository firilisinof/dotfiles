{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
in
{
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
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];
    runCheck = true;
    checkOpts = [ "--read-data-subset=1%" ];
  };

  systemd.services.restic-backups-b2.serviceConfig = {
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
