{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
  inherit (config.networking) domain;
  podman = lib.getExe config.virtualisation.podman.package;
  auth = config.services.kanidm.server.settings.origin;
  state = "/srv/games-state";
  games = "/srv/games";
  library = "${games}/library";
  staging = "/srv/media/downloads/romarr";
  network = "games";
  romarr = pkgs.callPackage ./packages/romarr.nix { };
  romarrState = "/var/lib/romarr";
  database = config.services.mysql.package;
  apps = {
    games = 8087;
    romarr = 6868;
    requestz = 3088;
  };
  url = lib.mapAttrs (name: _: "https://${name}.${domain}") apps // {
    prowlarr = "https://prowlarr.${domain}";
    torrents = "https://torrents.${domain}";
  };
  # the setup script reads these from its credentials directory
  setupCredentials = {
    romm-admin-password = "games/romm-admin-password";
    romarr-library-password = "games/romarr-library-password";
    ggrequestz-library-password = "games/ggrequestz-library-password";
    romarr-api-key = "games/romarr-api-key";
    prowlarr-password = "prowlarr/password";
    prowlarr-api-key = "prowlarr/api-key";
    qbittorrent-password = "qbittorrent/admin-password";
  };
  containers = [
    "ggrequestz-db"
    "ggrequestz"
  ];
  # starting romm.service alone leaves the units that require it stopped
  rommUnits = map (name: "${name}.service") [
    "romm"
    "romm-worker"
    "romm-scheduler"
    "romm-watcher"
  ];
  appUnits = [
    "podman-ggrequestz.service"
    "romarr.service"
  ]
  ++ rommUnits;
in
{
  imports = [
    ./identity.nix
  ];

  users.groups.media.gid = 987;
  networking.firewall.interfaces.games0 = {
    allowedTCPPorts = [
      53
      443
    ];
    allowedUDPPorts = [ 53 ];
  };
  users.users.romarr = {
    isSystemUser = true;
    uid = 807;
    group = "media";
  };
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
    "romarr-library-password"
    "ggrequestz-library-password"
    "romarr-password"
    "romarr-api-key"
    "ggrequestz-database-password"
    "ggrequestz-session-secret"
  ]) (_: { });

  sops.templates."romm.env".content = ''
    ROMM_AUTH_SECRET_KEY=${placeholder."games/romm-auth-secret"}
    IGDB_CLIENT_ID=${placeholder."games/igdb-client-id"}
    IGDB_CLIENT_SECRET=${placeholder."games/igdb-client-secret"}
    OIDC_CLIENT_SECRET=${placeholder."games/romm-oidc-secret"}
  '';
  sops.templates."romarr.env".content = ''
    ROMARR_PASSWORD=${placeholder."games/romarr-password"}
    ROMARR_API_KEY=${placeholder."games/romarr-api-key"}
    QBITTORRENT_PASS=${placeholder."qbittorrent/admin-password"}
    LIBRARY_PASSWORD=${placeholder."games/romarr-library-password"}
  '';
  sops.templates."ggrequestz.env".content = ''
    POSTGRES_PASSWORD=${placeholder."games/ggrequestz-database-password"}
    SESSION_SECRET=${placeholder."games/ggrequestz-session-secret"}
    IGDB_CLIENT_ID=${placeholder."games/igdb-client-id"}
    IGDB_CLIENT_SECRET=${placeholder."games/igdb-client-secret"}
    LIBRARY_PASSWORD=${placeholder."games/ggrequestz-library-password"}
    OIDC_CLIENT_SECRET=${placeholder."games/ggrequestz-oidc-secret"}
    REQUEST_WEBHOOK_URL=${url.romarr}/api/v1/webhook/ggrequestz?apikey=${
      placeholder."games/romarr-api-key"
    }
  '';

  systemd.tmpfiles.rules = [
    "d ${library}/roms 2770 romarr media - -"
    "d ${state} 0750 root root - -"
    "d ${state}/ggrequestz-database 0700 - - - -"
    "d ${staging} 2770 qbittorrent media - -"
    "d ${staging}/hub 2770 romarr media - -"
  ];
  # the library keeps ROMarr as its writer, and the module would hand it to RomM
  systemd.tmpfiles.settings."10-romm" = {
    ${games}.d.mode = lib.mkForce "2750";
    ${library}.d = {
      mode = lib.mkForce "2770";
      user = lib.mkForce "romarr";
    };
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
    nginx.virtualHost = "games.${domain}";
    environmentFile = config.sops.templates."romm.env".path;
    extraEnvironment = {
      ROMM_DB_DRIVER = "mariadb";
      # the password is required but unused, MariaDB authenticates the socket peer
      DB_PASSWD = "socket-authentication";
      DB_QUERY_JSON = builtins.toJSON { unix_socket = "/run/mysqld/mysqld.sock"; };
      ROMM_BASE_URL = url.games;
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
      OIDC_REDIRECT_URI = "${url.games}/api/oauth/openid";
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
  services.nginx.virtualHosts."games.${domain}".listen = [
    {
      addr = "127.0.0.1";
      port = apps.games;
    }
  ];

  virtualisation.oci-containers.containers = {
    ggrequestz-db = {
      image = "docker.io/library/postgres@sha256:aae6554de426ae1990f1a939ff183a0299146cf7142a6f4c379c3357af9cc2d8";
      autoRemoveOnStop = false;
      networks = [ network ];
      environment = {
        POSTGRES_DB = "ggrequestz";
        POSTGRES_USER = "ggrequestz";
        POSTGRES_PASSWORD_FILE = "/run/secrets/password";
        POSTGRES_INITDB_ARGS = "--encoding=UTF-8 --lc-collate=C --lc-ctype=C";
      };
      volumes = [
        "${state}/ggrequestz-database:/var/lib/postgresql/data"
        "${secrets."games/ggrequestz-database-password".path}:/run/secrets/password:ro"
      ];
    };
    ggrequestz = {
      image = "ghcr.io/xtreemmak/ggrequestz@sha256:32a55965b4d76bbe3dc8d0552afd882f74d6ed8c494ee6a4355ba7573f038466";
      autoRemoveOnStop = false;
      networks = [ network ];
      dependsOn = [ "ggrequestz-db" ];
      ports = [ "127.0.0.1:3088:3000" ];
      environmentFiles = [ config.sops.templates."ggrequestz.env".path ];
      environment = {
        NODE_ENV = "production";
        TZ = config.time.timeZone;
        POSTGRES_HOST = "ggrequestz-db";
        POSTGRES_PORT = "5432";
        POSTGRES_DB = "ggrequestz";
        POSTGRES_USER = "ggrequestz";
        POSTGRES_POOL_MAX = "5";
        PM2_INSTANCES = "1";
        AUTO_MIGRATE = "true";
        AUTH_METHOD = "oidc";
        OIDC_ISSUER_URL = "${auth}/oauth2/openid/ggrequestz";
        OIDC_CLIENT_ID = "ggrequestz";
        OIDC_PROVIDER_NAME = "Kanidm";
        OIDC_REDIRECT_URI = "${url.requestz}/api/auth/callback";
        OIDC_GROUPS_CLAIM = "games_role";
        OIDC_ROLE_MAP = "admin:admin";
        PUBLIC_SITE_URL = url.requestz;
        ORIGIN = url.requestz;
        LIBRARY_KIND = "romm";
        LIBRARY_URL = url.games;
        LIBRARY_PUBLIC_URL = url.games;
        LIBRARY_USERNAME = "ggrequestz";
        LIBRARY_SYNC_ENABLED = "true";
        LIBRARY_SYNC_INTERVAL_MS = "300000";
      };
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs (map (name: "podman-${name}") containers) (_: {
      requires = [ "podman-network-games.service" ];
      after = [ "podman-network-games.service" ];
    }))
    (lib.genAttrs (map (lib.removeSuffix ".service") rommUnits) (_: {
      # ROMarr writes to the library through the media group
      serviceConfig.UMask = "0007";
    }))
    {
      romm = {
        requires = [ "mysql.service" ];
        after = [ "mysql.service" ];
      };
      romarr = {
        description = "ROMarr game acquisition";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          ROMARR_HOST = "127.0.0.1";
          ROMARR_PORT = toString apps.romarr;
          ROMARR_DATA = "${romarrState}/romarr.json";
          # installed plugins live with the settings
          ROM_HUB_HOME = "${romarrState}/rom-hub";
          LIBRARY_KIND = "romm";
          LIBRARY_URL = url.games;
          LIBRARY_USERNAME = "romarr";
          LIBRARY_PATH = "${library}/roms";
          QBITTORRENT_URL = "${url.torrents}:443";
          QBITTORRENT_USER = "lucas";
          QBITTORRENT_CATEGORY = "romarr";
          GGREQUESTZ_URL = url.requestz;
          ROMARR_PLAYERS = "none";
        };
        serviceConfig = {
          ExecStart = lib.getExe romarr;
          EnvironmentFile = config.sops.templates."romarr.env".path;
          User = "romarr";
          Group = "media";
          UMask = "0007";
          StateDirectory = "romarr";
          StateDirectoryMode = "0700";
          WorkingDirectory = romarrState;
          Restart = "on-failure";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            "${library}/roms"
            staging
          ];
        };
      };
      podman-network-games = {
        description = "Create the private game services network";
        wantedBy = [ "multi-user.target" ];
        path = [ config.virtualisation.podman.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          if ! podman network exists ${network}; then
            podman network create --interface-name games0 ${network}
          fi
        '';
      };
      games-setup = {
        description = "Connect the game library, acquisition services, and sources";
        wantedBy = [ "multi-user.target" ];
        wants = appUnits ++ [
          "prowlarr.service"
          "qbittorrent.service"
          "caddy.service"
        ];
        after = appUnits ++ [
          "prowlarr.service"
          "qbittorrent.service"
          "caddy.service"
        ];
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
    stopUnits = [ "games-setup.service" ] ++ appUnits;
    paths = [ romarrState ];
    dumps."romm.sql" =
      "${lib.getExe' database "mariadb-dump"} --single-transaction --quick --routines --events --triggers --databases romm";
    dumps."ggrequestz.dump" = "${podman} exec ggrequestz-db pg_dump -U ggrequestz -d ggrequestz -Fc";
    exclude = [
      "${state}/ggrequestz-database"
      # container data kept until the native service is confirmed
      "${state}/romarr"
      "${games}/resources"
      "${games}/cache"
    ];
  };
  services.caddy.virtualHosts = lib.mapAttrs' (
    name: port:
    lib.nameValuePair "${name}.${domain}" {
      extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
    }
  ) apps;

  dotfiles.monitors = [
    { target = "${url.games}/api/heartbeat"; }
    { target = "${url.romarr}/api/health"; }
    { target = "${url.requestz}/api/health"; }
  ];
}
