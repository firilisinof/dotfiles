{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.forgejo;
  hostname = "git.firilisinof.com";
  issuer = "${config.services.kanidm.server.settings.origin}/oauth2/openid/forgejo";
  releaseDirectory = "/srv/forgejo-releases";
  # a project with many large releases should be a choice, not a surprise on the b2 bill
  releaseLimitBytes = 20 * 1024 * 1024 * 1024;
in
{
  sops.secrets."forgejo/oidc-secret".restartUnits = [ "forgejo.service" ];

  services.forgejo = {
    enable = true;
    stateDir = "/srv/forgejo";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = hostname;
        ROOT_URL = "https://${hostname}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
      };
      service = {
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        ENABLE_INTERNAL_SIGNIN = false;
        REQUIRE_SIGNIN_VIEW = true;
      };
      oauth2_client.ENABLE_AUTO_REGISTRATION = true;
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };
      repository.ENABLE_PUSH_CREATE_USER = true;
      session.COOKIE_SECURE = true;
      # large mirrors over wi-fi exceed the 10 and 5 minute defaults
      "git.timeout" = {
        MIGRATE = 3600;
        MIRROR = 3600;
      };
    };
  };

  # kanidm provisions the client, and the group claim grants the instance admin role
  systemd.services.forgejo = {
    after = [ "kanidm.service" ];
    serviceConfig.LoadCredential = [
      "oidc-secret:${config.sops.secrets."forgejo/oidc-secret".path}"
    ];
    # the module has no option for authentication sources
    preStart = lib.mkAfter ''
      options=(
        --name kanidm
        --provider openidConnect
        --key forgejo
        --secret "$(<"$CREDENTIALS_DIRECTORY/oidc-secret")"
        --auto-discover-url ${issuer}/.well-known/openid-configuration
        --scopes email
        --scopes profile
        --group-claim-name forgejo_role
        --admin-group admin
      )
      id=$(forgejo admin auth list | sed -n 's/^\([0-9]\+\)[[:space:]]\+kanidm[[:space:]].*/\1/p')
      if [ -n "$id" ]; then
        forgejo admin auth update-oauth --id "$id" "''${options[@]}"
      else
        forgejo admin auth add-oauth "''${options[@]}"
      fi
    '';
  };

  # mirrors carry only git data, so github release files are archived beside them
  systemd.services.forgejo-releases = {
    description = "Archive GitHub release files of Forgejo mirrors";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.git ];
    serviceConfig = {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
      ExecStart = "${pkgs.python3}/bin/python3 ${./releases.py} ${cfg.repositoryRoot} ${releaseDirectory} ${toString releaseLimitBytes}";
      UMask = "0027";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ releaseDirectory ];
    };
  };

  systemd.timers.forgejo-releases = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5m";
      Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [
    # glance watches this directory, which forgejo would create only with the first repository
    "d ${cfg.repositoryRoot}/lucas 0750 ${cfg.user} ${cfg.group} - -"
    # setgid keeps the archive readable by lucas, who stays out of the forgejo group and its secrets
    "d ${releaseDirectory} 2750 ${cfg.user} users - -"
  ];

  services.openssh.settings.AllowUsers = [ cfg.user ];

  services.restic.backups.b2 = {
    exclude = [
      "${cfg.stateDir}/data/forgejo.db*"
      "${cfg.stateDir}/data/tmp"
      "${cfg.stateDir}/log"
      "${releaseDirectory}/**/*.part"
    ];
    sqlite.forgejo = {
      inherit (cfg.database) path;
      inherit (cfg) user;
    };
  };

  services.caddy.virtualHosts.${hostname} = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy ${cfg.settings.server.HTTP_ADDR}:${toString cfg.settings.server.HTTP_PORT}";
  };
}
