{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kanidm;
  hostname = "auth.firilisinof.com";
  origin = "https://${hostname}";
  forgejoOrigin = "https://git.firilisinof.com";
  tlsDirectory = config.security.acme.certs."firilisinof.com".directory;
  identity = config.home-manager.users.lucas.programs.git.settings.user;
in
{
  sops.secrets =
    lib.genAttrs
      [
        "kanidm/admin-password"
        "kanidm/idm-admin-password"
        "forgejo/oidc-secret"
      ]
      (_: {
        group = "kanidm";
        mode = "0440";
        restartUnits = [ "kanidm.service" ];
      });

  services.kanidm = {
    package = pkgs.kanidm_1_12.withSecretProvisioning;
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
        "forgejo.users" = { };
        "forgejo.admins" = { };
      };
      persons.lucas = {
        displayName = identity.name;
        mailAddresses = [ identity.email ];
        groups = [
          "forgejo.users"
          "forgejo.admins"
        ];
      };
      systems.oauth2.forgejo = {
        displayName = "Forgejo";
        originUrl = "${forgejoOrigin}/user/oauth2/kanidm/callback";
        originLanding = "${forgejoOrigin}/";
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
    extraConfig = ''
      reverse_proxy https://${cfg.server.settings.bindaddress} {
        transport http {
          tls_server_name ${hostname}
        }
      }
    '';
  };

  # public, since the AI apps' servers fetch its metadata and exchange login codes for tokens
  dotfiles.tunnel.ingress.${hostname} = {
    service = "https://${cfg.server.settings.bindaddress}";
    originRequest.originServerName = hostname;
  };
  # the pi5's own clients, such as provisioning at startup, reach it through Caddy rather than the tunnel
  networking.hosts."100.74.192.104" = [ hostname ];

  services.restic.backups.b2 = {
    paths = [ cfg.server.settings.online_backup.path ];
  };
}
