{
  config,
  lib,
  ...
}:

let
  cfg = config.services.forgejo;
  hostname = "git.${config.networking.domain}";
  origin = "https://${hostname}";
  issuer = "${config.services.kanidm.server.settings.origin}/oauth2/openid/forgejo";
in
{
  sops.secrets."forgejo/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [
      "kanidm.service"
      "forgejo.service"
    ];
  };

  # the group claim grants the instance admin role
  services.kanidm.provision = {
    groups."forgejo.users" = { };
    groups."forgejo.admins" = { };
    persons.lucas.groups = [
      "forgejo.users"
      "forgejo.admins"
    ];
    systems.oauth2.forgejo = {
      displayName = "Forgejo";
      originUrl = "${origin}/user/oauth2/kanidm/callback";
      originLanding = "${origin}/";
      basicSecretFile = config.sops.secrets."forgejo/oidc-secret".path;
      preferShortUsername = true;
      scopeMaps."forgejo.users" = [
        "openid"
        "email"
        "profile"
      ];
      claimMaps.forgejo_role.valuesByGroup."forgejo.admins" = [ "admin" ];
    };
  };

  services.forgejo = {
    enable = true;
    stateDir = "/srv/forgejo";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = hostname;
        ROOT_URL = "${origin}/";
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

  services.openssh.settings.AllowUsers = [ cfg.user ];

  services.restic.backups.b2 = {
    exclude = [
      "${cfg.stateDir}/data/forgejo.db*"
      "${cfg.stateDir}/data/tmp"
      "${cfg.stateDir}/log"
    ];
    sqlite.forgejo = {
      inherit (cfg.database) path;
      inherit (cfg) user;
    };
  };

  services.caddy.virtualHosts.${hostname}.extraConfig =
    "reverse_proxy ${cfg.settings.server.HTTP_ADDR}:${toString cfg.settings.server.HTTP_PORT}";

  dotfiles.monitors = [ { target = "${origin}/api/healthz"; } ];
}
