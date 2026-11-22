{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder;

  hostname = "yt.${config.networking.domain}";
  youtarr = pkgs.callPackage ./package.nix { };
  app = "${youtarr}/lib/youtarr";
  database = config.services.mysql.package;
  uid = 801;
  gid = 801;
  port = 3087;
  stateDir = "/srv/youtarr";
  mediaDir = "/srv/youtube";
  configDir = "${stateDir}/config";
  # the database records video paths under the directory the image used
  recordedMediaDir = "/usr/src/app/data";
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
  # seeds the settings once, and offers the preset login only until the application stores its own
  prepare = pkgs.writeShellScript "youtarr-prepare" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }
    config_file=${lib.escapeShellArg "${configDir}/config.json"}
    env_file=${lib.escapeShellArg appEnvPath}
    tmp_file="''${env_file}.tmp"

    if [ ! -e "$config_file" ]; then
      initial_tmp="''${config_file}.initial"
      install -o youtarr -g youtube -m 0640 ${initialConfig} "$initial_tmp"
      ln -T "$initial_tmp" "$config_file" 2>/dev/null || test -e "$config_file"
      rm -f "$initial_tmp"
    fi

    umask 0077
    if [ -f "$config_file" ] && grep -q '"passwordHash"[[:space:]]*:' "$config_file"; then
      : > "$tmp_file"
    else
      cat ${config.sops.templates."youtarr.env".path} > "$tmp_file"
    fi
    mv -f "$tmp_file" "$env_file"
  '';
in
{
  users.groups.youtube.gid = gid;
  users.users.youtarr = {
    inherit uid;
    isSystemUser = true;
    group = "youtube";
  };

  sops.secrets."youtarr/admin-password" = { };

  sops.templates."youtarr.env".content = ''
    AUTH_PRESET_USERNAME=lucas
    AUTH_PRESET_PASSWORD=${placeholder."youtarr/admin-password"}
  '';

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root - -"
    "d ${configDir} 0750 youtarr youtube - -"
    "d ${stateDir}/jobs 0750 youtarr youtube - -"
    "d ${stateDir}/images 0750 youtarr youtube - -"
    "d ${mediaDir} 2750 youtarr youtube - -"
  ];

  services.mysql = {
    ensureDatabases = [ "youtarr" ];
    ensureUsers = [
      {
        name = "youtarr";
        ensurePermissions."youtarr.*" = "ALL PRIVILEGES";
      }
    ];
  };

  systemd.services.youtarr = {
    description = "Youtarr YouTube archive";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "mysql.service" ];
    after = [
      "network-online.target"
      "mysql.service"
    ];
    environment = {
      HOST = "127.0.0.1";
      PORT = toString port;
      DB_SOCKET_PATH = "/run/mysqld/mysqld.sock";
      DB_HOST = "localhost";
      DB_PORT = "3306";
      DB_NAME = "youtarr";
      DB_USER = "youtarr";
      # the password is required but unused, MariaDB authenticates the socket peer
      DB_PASSWORD = "socket-authentication";
      AUTH_ENABLED = "true";
      YOUTUBE_OUTPUT_DIR = mediaDir;
      TZ = config.time.timeZone;
      # yt-dlp and deno keep caches under the home directory
      HOME = "/var/cache/youtarr";
    };
    serviceConfig = {
      ExecStartPre = "+${prepare}";
      ExecStart = lib.getExe youtarr;
      EnvironmentFile = "-${appEnvPath}";
      User = "youtarr";
      Group = "youtube";
      UMask = "0027";
      WorkingDirectory = app;
      CacheDirectory = "youtarr";
      CacheDirectoryMode = "0700";
      # upstream keeps its state beside the code, as the image's volumes did
      BindPaths = [
        "${configDir}:${app}/config"
        "${stateDir}/jobs:${app}/jobs"
        "${stateDir}/images:${app}/server/images"
        "${mediaDir}:${recordedMediaDir}"
      ];
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        configDir
        "${stateDir}/jobs"
        "${stateDir}/images"
        mediaDir
      ];
    };
  };

  services.restic.backups.b2 = {
    stopUnits = [ "youtarr.service" ];
    dumps."youtarr.sql" =
      "${lib.getExe' database "mariadb-dump"} --single-transaction --quick --routines --events --triggers --databases youtarr";
    exclude = [ "${mediaDir}/.youtarr_tmp" ];
  };

  services.caddy.virtualHosts.${hostname}.extraConfig = "reverse_proxy 127.0.0.1:${toString port}";

  dotfiles.monitors.${hostname} = {
    tcpPort = 443;
  };
}
