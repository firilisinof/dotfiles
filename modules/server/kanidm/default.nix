{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kanidm;
  inherit (config.networking) domain;
  hostname = "auth.${domain}";
  origin = "https://${hostname}";
  tlsDirectory = config.security.acme.certs.${domain}.directory;
  identity = config.home-manager.users.lucas.programs.git.settings.user;
in
{
  sops.secrets =
    lib.genAttrs
      [
        "kanidm/admin-password"
        "kanidm/idm-admin-password"
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
      # each service module adds its own groups and oauth2 client
      persons.lucas = {
        displayName = identity.name;
        mailAddresses = [ identity.email ];
      };
    };
  };

  users.users.kanidm.extraGroups = [ "acme" ];
  security.acme.certs.${domain}.reloadServices = [ "kanidm.service" ];

  systemd.services.kanidm = {
    after = [
      "acme-${domain}.service"
      "caddy.service"
    ];
    wants = [
      "acme-${domain}.service"
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
  networking.hosts.${config.dotfiles.tailscale.ipv4} = [ hostname ];

  services.restic.backups.b2 = {
    paths = [ cfg.server.settings.online_backup.path ];
  };

  dotfiles.monitors = [ { target = "${origin}/status"; } ];
}
