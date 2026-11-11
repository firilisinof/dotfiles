{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
  hostname = "securo.${config.networking.domain}";
  origin = "https://${hostname}";
  issuer = "${config.services.kanidm.server.settings.origin}/oauth2/openid/securo";
  state = "/srv/securo";
  podman = lib.getExe config.virtualisation.podman.package;
  # securo 0.18.0, pinned to the published arm64 images
  backendImage = "ghcr.io/securo-finance/securo-backend@sha256:2abf47902b81d9480be58ef41fde3b7bdd96dc85579e3162cd64efeab6d5f324";
  frontendImage = "ghcr.io/securo-finance/securo-frontend@sha256:7072dcd1ebbee2538e119f82b38ac6369c462c086e457219b0533a4753f8896d";
  appNames = [
    "securo-backend"
    "securo-worker"
    "securo-beat"
  ];
  appUnits = map (name: "podman-${name}.service") appNames;
  containers = appNames ++ [
    "securo-db"
    "securo-redis"
    "securo-frontend"
  ];
  backend = {
    image = backendImage;
    autoRemoveOnStop = false;
    networks = [ "securo" ];
    dependsOn = [
      "securo-db"
      "securo-redis"
    ];
    environmentFiles = [ config.sops.templates."securo.env".path ];
    environment = {
      TZ = config.time.timeZone;
      DEFAULT_CURRENCY = "EUR";
      FRONTEND_URL = origin;
      REDIS_URL = "redis://securo-redis:6379/0";
      STORAGE_LOCAL_PATH = "/app/data/attachments";
      ENABLE_BANKING_PRIVATE_KEY_FILE = "/run/secrets/enable-banking.pem";
      ENABLE_BANKING_OAUTH_REDIRECT_URI = "${origin}/oauth/callback";
      OIDC_ENABLED = "true";
      OIDC_PROVIDER_NAME = "Kanidm";
      OIDC_DISCOVERY_URL = "${issuer}/.well-known/openid-configuration";
      OIDC_CLIENT_ID = "securo";
      OIDC_REDIRECT_URI = "${origin}/api/auth/oidc/callback";
      OIDC_SCOPES = "openid email profile";
      OIDC_SYNC_ROLES = "true";
      OIDC_ROLES_CLAIM = "securo_role";
      OIDC_ADMIN_ROLES = "admin";
      LOCAL_AUTH_ENABLED = "false";
      # only the kanidm securo group can register through oidc
      REGISTRATION_ENABLED = "true";
      TRUSTED_PROXY_HOPS = "1";
      AGENTS_ENABLED = "false";
    };
    volumes = [
      "${state}/attachments:/app/data/attachments"
      "${secrets."securo/enable-banking-private-key".path}:/run/secrets/enable-banking.pem:ro"
    ];
    extraOptions = [
      "--add-host=auth.${config.networking.domain}:${config.dotfiles.tailscale.ipv4}"
    ];
  };
  waitFor = command: ''
    for attempt in $(${lib.getExe' pkgs.coreutils "seq"} 1 60); do
      if ${command}; then
        exit 0
      fi
      ${lib.getExe' pkgs.coreutils "sleep"} 2
    done
    echo "Securo dependency did not become ready" >&2
    exit 1
  '';
in
{
  sops.secrets."securo/secret-key".restartUnits = appUnits;
  sops.secrets."securo/pluggy-client-id".restartUnits = appUnits;
  sops.secrets."securo/pluggy-client-secret".restartUnits = appUnits;
  sops.secrets."securo/enable-banking-app-id".restartUnits = appUnits;
  sops.secrets."securo/enable-banking-private-key".restartUnits = appUnits;
  sops.secrets."securo/database-password".restartUnits = appUnits ++ [ "podman-securo-db.service" ];
  sops.secrets."securo/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = appUnits ++ [ "kanidm.service" ];
  };
  sops.templates."securo.env".content = ''
    SECRET_KEY=${placeholder."securo/secret-key"}
    DATABASE_URL=postgresql+asyncpg://securo:${
      placeholder."securo/database-password"
    }@securo-db:5432/securo
    OIDC_CLIENT_SECRET=${placeholder."securo/oidc-secret"}
    PLUGGY_CLIENT_ID=${placeholder."securo/pluggy-client-id"}
    PLUGGY_CLIENT_SECRET=${placeholder."securo/pluggy-client-secret"}
    ENABLE_BANKING_APP_ID=${placeholder."securo/enable-banking-app-id"}
  '';

  services.kanidm.provision = {
    groups."securo.admins" = { };
    persons.lucas.groups = [ "securo.admins" ];
    systems.oauth2.securo = {
      displayName = "Securo";
      originUrl = "${origin}/api/auth/oidc/callback";
      originLanding = "${origin}/";
      basicSecretFile = secrets."securo/oidc-secret".path;
      preferShortUsername = true;
      scopeMaps."securo.admins" = [
        "openid"
        "email"
        "profile"
      ];
      claimMaps.securo_role.valuesByGroup."securo.admins" = [ "admin" ];
    };
  };

  networking.firewall.interfaces.securo0 = {
    allowedTCPPorts = [
      53
      443
    ];
    allowedUDPPorts = [ 53 ];
  };

  systemd.tmpfiles.rules = map (path: "d ${state}/${path} 0700 root root - -") [
    ""
    "database"
    "attachments"
    "beat"
  ];

  virtualisation.oci-containers.containers = {
    securo-db = {
      image = "docker.io/pgvector/pgvector@sha256:016a18f2a5269b23ca05de83826094011cc4e1a9e9cb28c186a3ba9f079ef1d9";
      autoRemoveOnStop = false;
      networks = [ "securo" ];
      environment = {
        POSTGRES_DB = "securo";
        POSTGRES_USER = "securo";
        POSTGRES_PASSWORD_FILE = "/run/secrets/password";
        POSTGRES_INITDB_ARGS = "--encoding=UTF-8 --lc-collate=C --lc-ctype=C";
      };
      volumes = [
        "${state}/database:/var/lib/postgresql/data"
        "${secrets."securo/database-password".path}:/run/secrets/password:ro"
      ];
    };
    securo-redis = {
      image = "docker.io/library/redis@sha256:59a18e562bbc0397a0e62217538c915e8df0bc7dd8aa7a5ae9247085794ae01e";
      networks = [ "securo" ];
      cmd = [
        "redis-server"
        "--save"
        ""
        "--appendonly"
        "no"
      ];
    };
    securo-backend = backend // {
      ports = [ "127.0.0.1:8091:8000" ];
      cmd = [
        "sh"
        "-c"
        "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"
      ];
    };
    securo-worker = backend // {
      dependsOn = [ "securo-backend" ];
      cmd = [
        "celery"
        "-A"
        "app.worker"
        "worker"
        "--loglevel=info"
        "--concurrency=2"
      ];
    };
    securo-beat = backend // {
      dependsOn = [ "securo-backend" ];
      volumes = backend.volumes ++ [ "${state}/beat:/app/data/beat" ];
      cmd = [
        "celery"
        "-A"
        "app.worker"
        "beat"
        "--loglevel=info"
        "--schedule=/app/data/beat/celerybeat-schedule"
      ];
    };
    securo-frontend = {
      image = frontendImage;
      networks = [ "securo" ];
      dependsOn = [ "securo-backend" ];
      ports = [ "127.0.0.1:3089:8080" ];
      environment = {
        BACKEND_URL = "http://securo-backend:8000";
        FRONTEND_URL = origin;
      };
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs (map (name: "podman-${name}") containers) (_: {
      requires = [ "podman-network-securo.service" ];
      after = [ "podman-network-securo.service" ];
    }))
    (lib.genAttrs [ "podman-securo-worker" "podman-securo-beat" "podman-securo-frontend" ] (_: {
      preStart = lib.mkAfter (
        waitFor ''${podman} exec securo-backend python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=2)" >/dev/null 2>&1''
      );
      serviceConfig.TimeoutStartSec = lib.mkForce "5min";
    }))
    {
      podman-network-securo = {
        description = "Create the private Securo network";
        wantedBy = [ "multi-user.target" ];
        path = [ config.virtualisation.podman.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          if ! podman network exists securo; then
            podman network create --interface-name securo0 securo
          fi
        '';
      };
      podman-securo-backend = {
        preStart = lib.mkAfter (
          waitFor "${podman} exec securo-db pg_isready -U securo -d securo >/dev/null 2>&1 && ${podman} exec securo-redis redis-cli ping >/dev/null 2>&1"
        );
        serviceConfig.TimeoutStartSec = lib.mkForce "5min";
      };
    }
  ];

  services.caddy.virtualHosts.${hostname}.extraConfig = ''
    handle /api/* {
      reverse_proxy 127.0.0.1:8091
    }
    handle {
      reverse_proxy 127.0.0.1:3089
    }
  '';

  services.restic.backups.b2 = {
    stopUnits = [ "podman-securo-frontend.service" ] ++ lib.reverseList appUnits;
    dumps."securo.dump" = "${podman} exec securo-db pg_dump -U securo -d securo -Fc";
    exclude = [
      "${state}/database"
      "${state}/beat"
    ];
  };

  dotfiles.monitors = [ { target = "${origin}/api/health"; } ];
}
