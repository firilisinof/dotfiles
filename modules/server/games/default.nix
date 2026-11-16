{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
  inherit (config.networking) domain;
  auth = config.services.kanidm.server.settings.origin;
  games = "/srv/games";
  library = "${games}/library";
  database = config.services.mysql.package;
  hostname = "games.${domain}";
  url = "https://${hostname}";
  port = 8087;
  # the setup script reads these from its credentials directory
  setupCredentials = {
    romm-admin-password = "games/romm-admin-password";
  };
  # starting romm.service alone leaves the units that require it stopped
  rommUnits = map (name: "${name}.service") [
    "romm"
    "romm-worker"
    "romm-scheduler"
    "romm-watcher"
  ];
in
{
  imports = [
    ./identity.nix
  ];

  users.groups.media.gid = 987;
  users.users.romm = {
    isSystemUser = true;
    uid = 808;
    group = "media";
  };

  sops.secrets = lib.genAttrs (map (name: "games/${name}") [
    "igdb-client-id"
    "igdb-client-secret"
    "romm-auth-secret"
    "romm-admin-password"
  ]) (_: { });

  sops.templates."romm.env".content = ''
    ROMM_AUTH_SECRET_KEY=${placeholder."games/romm-auth-secret"}
    IGDB_CLIENT_ID=${placeholder."games/igdb-client-id"}
    IGDB_CLIENT_SECRET=${placeholder."games/igdb-client-secret"}
    OIDC_CLIENT_SECRET=${placeholder."games/romm-oidc-secret"}
  '';
  systemd.tmpfiles.rules = [
    "d ${library}/roms 2770 romm media - -"
  ];
  # the media group adds files to the library, and the module would make it read-only for the group
  systemd.tmpfiles.settings."10-romm" = {
    ${games}.d.mode = lib.mkForce "2750";
    ${library}.d.mode = lib.mkForce "2770";
  };

  services.romm = {
    enable = true;
    group = "media";
    # upstream fixes the library at <dataDir>/library
    dataDir = games;
    database = {
      createLocally = false;
      host = "localhost";
      port = 3306;
    };
    nginx.virtualHost = hostname;
    environmentFile = config.sops.templates."romm.env".path;
    extraEnvironment = {
      ROMM_DB_DRIVER = "mariadb";
      # the password is required but unused, MariaDB authenticates the socket peer
      DB_PASSWD = "socket-authentication";
      DB_QUERY_JSON = builtins.toJSON { unix_socket = "/run/mysqld/mysqld.sock"; };
      ROMM_BASE_URL = url;
      # nginx serves /cache/ from <dataDir>/cache, and RomM derives its cache from this path
      ROMM_TMP_PATH = games;
      SCAN_WORKERS = "2";
      WEB_SERVER_CONCURRENCY = "2";
      HASHEOUS_API_ENABLED = "true";
      RESCAN_ON_FILESYSTEM_CHANGE_DELAY = "2";
      DISABLE_EMULATOR_JS = "true";
      DISABLE_RUFFLE_RS = "true";
      DISABLE_JSDOS = "true";
      DISABLE_PICO8 = "true";
      DISABLE_EASYRPG = "true";
      OIDC_ENABLED = "true";
      OIDC_PROVIDER = "Kanidm";
      OIDC_CLIENT_ID = "romm";
      OIDC_REDIRECT_URI = "${url}/api/oauth/openid";
      OIDC_SERVER_APPLICATION_URL = "${auth}/oauth2/openid/romm";
      OIDC_SERVER_METADATA_URL = "${auth}/oauth2/openid/romm/.well-known/openid-configuration";
      OIDC_CLAIM_ROLES = "games_role";
      OIDC_ROLE_ADMIN = "admin";
    };
  };
  services.mysql = {
    ensureDatabases = [ "romm" ];
    ensureUsers = [
      {
        name = "romm";
        ensurePermissions."romm.*" = "ALL PRIVILEGES";
      }
    ];
  };
  services.nginx.virtualHosts.${hostname}.listen = [
    {
      addr = "127.0.0.1";
      inherit port;
    }
  ];

  systemd.services = lib.mkMerge [
    (lib.genAttrs (map (lib.removeSuffix ".service") rommUnits) (_: {
      # files RomM adds to the library stay writable for the media group
      serviceConfig.UMask = "0007";
    }))
    {
      romm = {
        requires = [ "mysql.service" ];
        after = [ "mysql.service" ];
      };
      games-setup = {
        description = "Create the game library administrator";
        wantedBy = [ "multi-user.target" ];
        wants = rommUnits ++ [ "caddy.service" ];
        after = rommUnits ++ [ "caddy.service" ];
        environment = {
          GAMES_ADMIN_EMAIL = config.home-manager.users.lucas.programs.git.settings.user.email;
          GAMES_DOMAIN = domain;
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writers.writePython3 "games-setup" {
            # ruff formats the script, and these are the checks it disagrees with
            flakeIgnore = [
              "E203"
              "E501"
              "W503"
            ];
          } (builtins.readFile ./setup.py);
          LoadCredential = lib.mapAttrsToList (
            name: secret: "${name}:${secrets.${secret}.path}"
          ) setupCredentials;
          UMask = "0077";
          TimeoutStartSec = "10min";
        };
      };
    }
  ];

  services.restic.backups.b2 = {
    stopUnits = [ "games-setup.service" ] ++ rommUnits;
    dumps."romm.sql" =
      "${lib.getExe' database "mariadb-dump"} --single-transaction --quick --routines --events --triggers --databases romm";
    exclude = [
      "${games}/resources"
      "${games}/cache"
    ];
  };
  services.caddy.virtualHosts.${hostname}.extraConfig = "reverse_proxy 127.0.0.1:${toString port}";

  dotfiles.monitors = [ { target = "${url}/api/heartbeat"; } ];
}
