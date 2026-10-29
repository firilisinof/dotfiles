{
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.kanidm;
  hostname = "auth.firilisinof.com";
  origin = "https://${hostname}";
  kavitaOrigin = "https://read.firilisinof.com";
  tlsDirectory = config.security.acme.certs."firilisinof.com".directory;
  identity = config.home-manager.users.lucas.programs.git.settings.user;
in
{
  sops.secrets."kanidm/admin-password" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };
  sops.secrets."kanidm/idm-admin-password" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };
  sops.secrets."kavita/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };

  services.kanidm = {
    package = pkgs.kanidm_1_11.withSecretProvisioning;
    client = {
      enable = true;
      settings.uri = origin;
    };
    server = {
      enable = true;
      settings = {
        domain = hostname;
        inherit origin;
        bindaddress = "127.0.0.1:8445";
        tls_key = "${tlsDirectory}/key.pem";
        tls_chain = "${tlsDirectory}/fullchain.pem";
        http_client_address_info.x-forward-for = [ "127.0.0.1" ];
        online_backup = {
          path = "/var/backup/kanidm";
          schedule = "0 22 * * *";
          versions = 7;
        };
      };
    };
    provision = {
      enable = true;
      instanceUrl = origin;
      acceptInvalidCerts = false;
      adminPasswordFile = config.sops.secrets."kanidm/admin-password".path;
      idmAdminPasswordFile = config.sops.secrets."kanidm/idm-admin-password".path;
      groups = {
        "kavita.users" = { };
        "kavita.admins" = { };
      };
      persons.lucas = {
        displayName = identity.name;
        mailAddresses = [ identity.email ];
        groups = [
          "kavita.users"
          "kavita.admins"
        ];
      };
      systems.oauth2.kavita = {
        displayName = "Kavita";
        originUrl = [
          "${kavitaOrigin}/signin-oidc"
          "${kavitaOrigin}/signout-callback-oidc"
        ];
        originLanding = "${kavitaOrigin}/";
        basicSecretFile = config.sops.secrets."kavita/oidc-secret".path;
        preferShortUsername = true;
        scopeMaps."kavita.users" = [
          "openid"
          "email"
          "profile"
        ];
      };
    };
  };

  users.users.kanidm.extraGroups = [ "acme" ];
  security.acme.certs."firilisinof.com".reloadServices = [ "kanidm.service" ];

  systemd.services.kanidm = {
    after = [
      "acme-firilisinof.com.service"
      "caddy.service"
    ];
    wants = [
      "acme-firilisinof.com.service"
      "caddy.service"
    ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  services.caddy.virtualHosts.${hostname} = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = ''
      reverse_proxy https://${cfg.server.settings.bindaddress} {
        transport http {
          tls_server_name ${hostname}
        }
      }
    '';
  };

  services.restic.backups.b2 = {
    paths = [ cfg.server.settings.online_backup.path ];
  };
}
