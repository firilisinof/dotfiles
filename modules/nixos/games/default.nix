{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
  state = "/srv/games-state";
  library = "/srv/games/library";
  staging = "/srv/media/downloads/romarr";
  network = "games";
  databaseImage = "docker.io/library/mariadb@sha256:d1891ede5a559f1086f55053bb8cc1569b0298338c4d72d71725a7f74f6ba620";
  apps = {
    games = 8087;
    romarr = 6868;
    game-requests = 3088;
  };
  containers = [
    "romm-db"
    "ggrequestz-db"
    "romm"
    "romarr"
    "ggrequestz"
  ];
  appUnits = map (name: "podman-${name}.service") [
    "ggrequestz"
    "romarr"
    "romm"
  ];
in
{
  imports = [
    ./identity.nix
    ./prowlarr.nix
  ];

  users.groups.media.gid = 987;
  users.users.romarr = {
    isSystemUser = true;
    uid = 807;
    group = "media";
  };

  sops.secrets = lib.genAttrs (map (name: "games/${name}") [
    "igdb-client-id"
    "igdb-client-secret"
    "romm-database-password"
    "romm-database-root-password"
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
    DB_PASSWD=${placeholder."games/romm-database-password"}
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
    REQUEST_WEBHOOK_URL=http://romarr:6868/api/v1/webhook/ggrequestz?apikey=${
      placeholder."games/romarr-api-key"
    }
  '';
  sops.templates."romm-backup.cnf".content = ''
    [client]
    user=root
    password=${placeholder."games/romm-database-root-password"}
  '';

  systemd.tmpfiles.rules = [
    "d /srv/games 2750 root media - -"
    "d ${library} 2770 romarr media - -"
    "d ${library}/roms 2770 romarr media - -"
    "d ${library}/bios 2770 romarr media - -"
    "d /srv/games/preserved 0700 root root - -"
    "d ${state} 0750 root root - -"
    "d ${state}/romarr 0700 romarr media - -"
    "d ${state}/romm 0750 root root - -"
    "d ${state}/romm/resources 0750 root root - -"
    "d ${state}/romm/assets 0750 root root - -"
    "d ${state}/romm/config 0750 root root - -"
    "d ${state}/romm/redis 0750 root root - -"
    "d ${state}/romm/database 0700 - - - -"
    "d ${state}/ggrequestz-database 0700 - - - -"
    "d ${staging} 2770 qbittorrent media - -"
    "d ${staging}/hub 2770 romarr media - -"
    "d /var/backup/games 0700 root root - -"
  ];

  virtualisation.oci-containers.containers = {
    romm-db = {
      image = databaseImage;
      autoRemoveOnStop = false;
      networks = [ network ];
      environment = {
        MARIADB_DATABASE = "romm";
        MARIADB_USER = "romm";
        MARIADB_PASSWORD_FILE = "/run/secrets/password";
        MARIADB_ROOT_PASSWORD_FILE = "/run/secrets/root-password";
      };
      volumes = [
        "${state}/romm/database:/var/lib/mysql"
        "${secrets."games/romm-database-password".path}:/run/secrets/password:ro"
        "${secrets."games/romm-database-root-password".path}:/run/secrets/root-password:ro"
        "${config.sops.templates."romm-backup.cnf".path}:/run/secrets/backup.cnf:ro"
      ];
      cmd = [
        "--innodb-buffer-pool-size=128M"
        "--character-set-server=utf8mb4"
        "--collation-server=utf8mb4_unicode_ci"
        "--log-bin-trust-function-creators=1"
      ];
    };
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
    romm = {
      image = "docker.io/rommapp/romm@sha256:8677fb7b81b1d3db20b849e989a1dadc2a11159e51eb34a2acdcb01102274edf";
      autoRemoveOnStop = false;
      networks = [ network ];
      dependsOn = [ "romm-db" ];
      ports = [ "127.0.0.1:8087:8080" ];
      environmentFiles = [ config.sops.templates."romm.env".path ];
      environment = {
        DB_HOST = "romm-db";
        DB_NAME = "romm";
        DB_USER = "romm";
        TZ = config.time.timeZone;
        SCAN_WORKERS = "2";
        WEB_SERVER_CONCURRENCY = "2";
        HASHEOUS_API_ENABLED = "true";
        ENABLE_RESCAN_ON_FILESYSTEM_CHANGE = "true";
        RESCAN_ON_FILESYSTEM_CHANGE_DELAY = "2";
        DISABLE_EMULATOR_JS = "true";
        DISABLE_RUFFLE_RS = "true";
        DISABLE_JSDOS = "true";
        DISABLE_PICO8 = "true";
        DISABLE_EASYRPG = "true";
        OIDC_ENABLED = "true";
        OIDC_PROVIDER = "Kanidm";
        OIDC_CLIENT_ID = "romm";
        OIDC_REDIRECT_URI = "https://games.firilisinof.com/api/oauth/openid";
        OIDC_SERVER_APPLICATION_URL = "https://auth.firilisinof.com/oauth2/openid/romm";
        OIDC_SERVER_METADATA_URL = "https://auth.firilisinof.com/oauth2/openid/romm/.well-known/openid-configuration";
        OIDC_CLAIM_ROLES = "games_role";
        OIDC_ROLE_ADMIN = "admin";
      };
      volumes = [
        "${library}:/romm/library"
        "${state}/romm/resources:/romm/resources"
        "${state}/romm/assets:/romm/assets"
        "${state}/romm/config:/romm/config"
        "${state}/romm/redis:/redis-data"
      ];
      extraOptions = [ "--umask=0007" ];
    };
    romarr = {
      image = "ghcr.io/blizzhacker/romarr@sha256:19cbfad5189d630cc914eed1efb174dbd05c1888484b9ef6eb3698f71dc56458";
      autoRemoveOnStop = false;
      networks = [ network ];
      ports = [ "127.0.0.1:6868:6868" ];
      environmentFiles = [ config.sops.templates."romarr.env".path ];
      environment = {
        PUID = "807";
        PGID = "987";
        UMASK = "007";
        TZ = config.time.timeZone;
        LIBRARY_KIND = "romm";
        LIBRARY_URL = "http://romm:8080";
        LIBRARY_USERNAME = "romarr";
        LIBRARY_PATH = "${library}/roms";
        QBITTORRENT_URL = "https://torrents.firilisinof.com:443";
        QBITTORRENT_USER = "lucas";
        QBITTORRENT_CATEGORY = "romarr";
        GGREQUESTZ_URL = "https://game-requests.firilisinof.com";
        ROMARR_PLAYERS = "none";
      };
      volumes = [
        "${state}/romarr:/config"
        "${library}/roms:${library}/roms"
        "${staging}:${staging}"
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
        OIDC_ISSUER_URL = "https://auth.firilisinof.com/oauth2/openid/ggrequestz";
        OIDC_CLIENT_ID = "ggrequestz";
        OIDC_PROVIDER_NAME = "Kanidm";
        OIDC_REDIRECT_URI = "https://game-requests.firilisinof.com/api/auth/callback";
        OIDC_GROUPS_CLAIM = "games_role";
        OIDC_ROLE_MAP = "admin:admin";
        PUBLIC_SITE_URL = "https://game-requests.firilisinof.com";
        ORIGIN = "https://game-requests.firilisinof.com";
        LIBRARY_KIND = "romm";
        LIBRARY_URL = "http://romm:8080";
        LIBRARY_PUBLIC_URL = "https://games.firilisinof.com";
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
    {
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
            podman network create ${network}
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
        environment.GAMES_ADMIN_EMAIL = config.home-manager.users.lucas.programs.git.settings.user.email;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.python3}/bin/python3 ${./setup.py}";
          UMask = "0077";
          TimeoutStartSec = "10min";
        };
      };
      restic-backups-b2.preStart = lib.mkAfter ''
        set -eu
        umask 077
        directory=/var/backup/games
        rm -f "$directory/romm.sql.tmp" "$directory/ggrequestz.dump.tmp"
        trap 'rm -f "$directory/romm.sql.tmp" "$directory/ggrequestz.dump.tmp"' EXIT
        ${lib.getExe config.virtualisation.podman.package} exec romm-db \
          mariadb-dump --defaults-extra-file=/run/secrets/backup.cnf \
          --single-transaction --quick --routines --events --triggers --databases romm > "$directory/romm.sql.tmp"
        ${lib.getExe config.virtualisation.podman.package} exec ggrequestz-db \
          pg_dump -U ggrequestz -d ggrequestz -Fc > "$directory/ggrequestz.dump.tmp"
        test -s "$directory/romm.sql.tmp"
        test -s "$directory/ggrequestz.dump.tmp"
        mv "$directory/romm.sql.tmp" "$directory/romm.sql"
        mv "$directory/ggrequestz.dump.tmp" "$directory/ggrequestz.dump"
        trap - EXIT
      '';
    }
  ];

  services.restic.backups.b2 = {
    stopUnits = [ "games-setup.service" ] ++ appUnits;
    paths = [ "/var/backup/games" ];
    exclude = [
      "${state}/romm/database"
      "${state}/ggrequestz-database"
      "${state}/romm/redis"
      "${state}/romm/resources"
    ];
  };
  services.caddy.virtualHosts = lib.mapAttrs' (
    name: port:
    lib.nameValuePair "${name}.firilisinof.com" {
      extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
    }
  ) apps;
}
