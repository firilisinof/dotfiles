{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder secrets;
  inherit (pkgs) securo;
  hostname = "securo.${config.networking.domain}";
  origin = "https://${hostname}";
  issuer = "${config.services.kanidm.server.settings.origin}/oauth2/openid/securo";
  state = "/var/lib/securo";
  port = 8091;
  redisPort = 6380;
  postgresql = config.services.postgresql.package;
  # the scheduler and the worker start after the api has migrated the database
  appUnits = [
    "securo-backend.service"
    "securo-worker.service"
    "securo-beat.service"
  ];
  service = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [
      "postgresql.target"
      "redis-securo.service"
    ];
    after = [
      "network-online.target"
      "postgresql.target"
      "redis-securo.service"
    ];
    environment = {
      # the application is not installed into the environment, as in the image
      PYTHONPATH = securo.backend;
      TZ = config.time.timeZone;
      DEFAULT_CURRENCY = "EUR";
      FRONTEND_URL = origin;
      DATABASE_URL = "postgresql+asyncpg://securo@/securo?host=/run/postgresql";
      REDIS_URL = "redis://127.0.0.1:${toString redisPort}/0";
      STORAGE_LOCAL_PATH = "${state}/attachments";
      # pydantic would otherwise look for settings among the files in /run/secrets
      CREDENTIALS_DIRECTORY = "/var/empty";
      ENABLE_BANKING_PRIVATE_KEY_FILE = secrets."securo/enable-banking-private-key".path;
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
    serviceConfig = {
      EnvironmentFile = config.sops.templates."securo.env".path;
      User = "securo";
      Group = "securo";
      WorkingDirectory = securo.backend;
      StateDirectory = [
        "securo"
        "securo/attachments"
        "securo/beat"
      ];
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };
in
{
  users.groups.securo = { };
  users.users.securo = {
    isSystemUser = true;
    group = "securo";
    home = state;
  };

  sops.secrets."securo/secret-key".restartUnits = appUnits;
  sops.secrets."securo/pluggy-client-id".restartUnits = appUnits;
  sops.secrets."securo/pluggy-client-secret".restartUnits = appUnits;
  sops.secrets."securo/openexchangerates-app-id".restartUnits = appUnits;
  sops.secrets."securo/enable-banking-app-id".restartUnits = appUnits;
  sops.secrets."securo/enable-banking-private-key" = {
    owner = "securo";
    restartUnits = appUnits;
  };
  sops.secrets."securo/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = appUnits ++ [ "kanidm.service" ];
  };
  sops.templates."securo.env".content = ''
    SECRET_KEY=${placeholder."securo/secret-key"}
    OIDC_CLIENT_SECRET=${placeholder."securo/oidc-secret"}
    PLUGGY_CLIENT_ID=${placeholder."securo/pluggy-client-id"}
    PLUGGY_CLIENT_SECRET=${placeholder."securo/pluggy-client-secret"}
    OPENEXCHANGERATES_APP_ID=${placeholder."securo/openexchangerates-app-id"}
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

  services.postgresql = {
    extensions = ps: [ ps.pgvector ];
    ensureDatabases = [ "securo" ];
    ensureUsers = [
      {
        name = "securo";
        ensureDBOwnership = true;
      }
    ];
  };
  # the queue holds nothing that must survive a restart
  services.redis.servers.securo = {
    enable = true;
    bind = "127.0.0.1";
    port = redisPort;
    save = [ ];
    appendOnly = false;
  };

  systemd.services = {
    securo-backend = lib.recursiveUpdate service {
      description = "Securo API";
      serviceConfig = {
        ExecStartPre = "${securo.env}/bin/alembic upgrade head";
        ExecStart = "${securo.env}/bin/uvicorn app.main:app --host 127.0.0.1 --port ${toString port}";
      };
    };
    securo-worker = lib.recursiveUpdate service {
      description = "Securo background worker";
      wants = service.wants ++ [ "securo-backend.service" ];
      after = service.after ++ [ "securo-backend.service" ];
      serviceConfig.ExecStart = "${securo.env}/bin/celery -A app.worker worker --loglevel=info --concurrency=2";
    };
    securo-beat = lib.recursiveUpdate service {
      description = "Securo scheduler";
      wants = service.wants ++ [ "securo-backend.service" ];
      after = service.after ++ [ "securo-backend.service" ];
      serviceConfig.ExecStart = "${securo.env}/bin/celery -A app.worker beat --loglevel=info --schedule=${state}/beat/celerybeat-schedule";
    };
  };

  # the image's nginx only served these files and proxied the api
  services.caddy.virtualHosts.${hostname}.extraConfig = ''
    handle /api/* {
      reverse_proxy 127.0.0.1:${toString port}
    }
    handle {
      root * ${securo.frontend}
      route {
        try_files {path} /index.html
        header /index.html Cache-Control "no-store, no-cache, must-revalidate"
        file_server
      }
    }
  '';

  services.restic.backups.b2 = {
    stopUnits = lib.reverseList appUnits;
    paths = [ state ];
    dumps."securo.dump" =
      "${lib.getExe' pkgs.util-linux "runuser"} -u postgres -- ${lib.getExe' postgresql "pg_dump"} -Fc securo";
    exclude = [ "${state}/beat" ];
  };

  dotfiles.monitors = [ { target = "${origin}/api/health"; } ];
}
