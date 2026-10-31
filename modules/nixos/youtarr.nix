{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;

  appName = "youtarr";
  databaseName = "youtarr-db";
  networkName = "youtarr";
  uid = 801;
  gid = 801;
  stateDir = "/srv/youtarr";
  mediaDir = "/srv/youtube";
  configDir = "${stateDir}/config";
  appEnvPath = "/run/youtarr.env";
  initialConfig = pkgs.writeText "youtarr-initial-config.json" (
    builtins.toJSON {
      channelAutoDownload = false;
      autoRemovalEnabled = false;
      preferredResolution = "1080";
      videoCodec = "h264";
      subtitlesEnabled = true;
      subtitleLanguage = "en,pt-BR,fr";
      writeVideoNfoFiles = true;
    }
  );
in
{
  users.groups.youtube.gid = gid;
  users.users.youtarr = {
    inherit uid;
    isSystemUser = true;
    group = "youtube";
  };

  sops.secrets."youtarr/database-password" = { };
  sops.secrets."youtarr/database-root-password" = { };
  sops.secrets."youtarr/admin-password" = { };

  sops.templates."youtarr.env".content = ''
    DB_PASSWORD=${placeholder."youtarr/database-password"}
    AUTH_PRESET_USERNAME=lucas
    AUTH_PRESET_PASSWORD=${placeholder."youtarr/admin-password"}
  '';

  sops.templates."youtarr-mariadb-backup.cnf" = {
    content = ''
      [client]
      user=root
      password=${placeholder."youtarr/database-root-password"}
    '';
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root - -"
    "d ${configDir} 0750 youtarr youtube - -"
    "d ${stateDir}/jobs 0750 youtarr youtube - -"
    "d ${stateDir}/images 0750 youtarr youtube - -"
    "d ${stateDir}/database 0750 root root - -"
    "d ${mediaDir} 2750 youtarr youtube - -"
    "d /var/backup/youtarr 0700 root root - -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      "youtarr-db" = {
        # MariaDB 11.4.13, official multi-architecture image (linux/arm64/v8 verified)
        image = "docker.io/library/mariadb@sha256:d1891ede5a559f1086f55053bb8cc1569b0298338c4d72d71725a7f74f6ba620";
        autoRemoveOnStop = false;
        networks = [ networkName ];
        environment = {
          MARIADB_DATABASE = "youtarr";
          MARIADB_USER = "youtarr";
          MARIADB_ROOT_PASSWORD_FILE = "/run/secrets/database-root-password";
          MARIADB_PASSWORD_FILE = "/run/secrets/database-password";
          TZ = "Europe/Paris";
        };
        volumes = [
          "${stateDir}/database:/var/lib/mysql"
          "${secrets."youtarr/database-password".path}:/run/secrets/database-password:ro"
          "${secrets."youtarr/database-root-password".path}:/run/secrets/database-root-password:ro"
          "${config.sops.templates."youtarr-mariadb-backup.cnf".path}:/run/secrets/backup.cnf:ro"
        ];
        extraOptions = [
          "--health-cmd=healthcheck.sh --connect --innodb_initialized"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=5"
          "--health-start-period=30s"
        ];
      };

      ${appName} = {
        # Youtarr v1.90.2, linux/arm64 image in the pinned manifest list
        image = "docker.io/dialmaster/youtarr@sha256:b50bf3ddf4887abfb3a0adfbb7984bd25a422abe10fb71a58a326caa2d971bf4";
        user = "${toString uid}:${toString gid}";
        autoRemoveOnStop = false;
        dependsOn = [ databaseName ];
        networks = [ networkName ];
        environment = {
          DB_HOST = databaseName;
          DB_PORT = "3306";
          DB_NAME = "youtarr";
          DB_USER = "youtarr";
          AUTH_ENABLED = "true";
          YOUTUBE_OUTPUT_DIR = mediaDir;
          TZ = "Europe/Paris";
        };
        ports = [ "127.0.0.1:3087:3011" ];
        volumes = [
          "${mediaDir}:/usr/src/app/data"
          "${configDir}:/app/config"
          "${stateDir}/jobs:/app/jobs"
          "${stateDir}/images:/app/server/images"
        ];
        extraOptions = [
          "--env-file=${appEnvPath}"
          "--umask=0027"
        ];
      };
    };
  };

  systemd.services = {
    "podman-${appName}" = {
      requires = [
        "podman-${databaseName}.service"
        "podman-network-${networkName}.service"
      ];
      after = [
        "podman-${databaseName}.service"
        "podman-network-${networkName}.service"
      ];
      path = [
        pkgs.coreutils
        pkgs.gnugrep
      ];
      preStart = ''
        set -eu
        config_file=${lib.escapeShellArg "${configDir}/config.json"}
        env_file=${lib.escapeShellArg appEnvPath}
        tmp_file="''${env_file}.tmp"
        install -d -m 0700 /run/youtarr

        if [ ! -e "$config_file" ]; then
          initial_tmp="''${config_file}.initial"
          install -o youtarr -g youtube -m 0640 ${initialConfig} "$initial_tmp"
          ln -T "$initial_tmp" "$config_file" 2>/dev/null || test -e "$config_file"
          rm -f "$initial_tmp"
        fi

        if [ -f "$config_file" ] && grep -q '"passwordHash"[[:space:]]*:' "$config_file"; then
          grep -v '^AUTH_PRESET_' ${config.sops.templates."youtarr.env".path} > "$tmp_file"
        else
          cat ${config.sops.templates."youtarr.env".path} > "$tmp_file"
        fi
        chmod 0600 "$tmp_file"
        mv -f "$tmp_file" "$env_file"
      '';
      serviceConfig = {
        UMask = "0027";
      };
    };

    "podman-${databaseName}" = {
      requires = [ "podman-network-${networkName}.service" ];
      after = [ "podman-network-${networkName}.service" ];
    };

    "podman-network-${networkName}" = {
      description = "Create the private Youtarr Podman network";
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-${databaseName}.service"
        "podman-${appName}.service"
      ];
      path = [ config.virtualisation.podman.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! podman network exists ${networkName}; then
          podman network create ${networkName}
        fi
      '';
    };

    "restic-backups-b2" = {
      path = [
        config.virtualisation.podman.package
        pkgs.coreutils
        pkgs.systemd
      ];
      preStart = lib.mkAfter ''
        set -eu
        ${lib.getExe' pkgs.systemd "systemctl"} stop podman-${appName}.service
        dump=${lib.escapeShellArg "/var/backup/youtarr/youtarr.sql"}
        tmp="''${dump}.tmp"
        ${lib.getExe' pkgs.coreutils "rm"} -f "$dump" "$tmp"
        umask 077
        trap '${lib.getExe' pkgs.coreutils "rm"} -f "$tmp"' EXIT
        ${lib.getExe config.virtualisation.podman.package} exec ${databaseName} \
          mariadb-dump --defaults-extra-file=/run/secrets/backup.cnf \
          --single-transaction --quick --routines --events --triggers --databases youtarr > "$tmp"
        test -s "$tmp"
        ${lib.getExe' pkgs.coreutils "mv"} "$tmp" "$dump"
        trap - EXIT
      '';
      postStop = lib.mkAfter ''
        ${lib.getExe' pkgs.systemd "systemctl"} start podman-${appName}.service
      '';
    };
  };

  services.restic.backups.b2 = {
    paths = [ "/var/backup/youtarr" ];
    exclude = [
      "${stateDir}/database"
      "${mediaDir}/.youtarr_tmp"
    ];
  };

  services.caddy.virtualHosts."archive.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy 127.0.0.1:3087";
  };
}
