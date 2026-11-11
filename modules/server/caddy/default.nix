{ config, lib, ... }:

let
  inherit (config.networking) domain;
  tailscale = config.dotfiles.tailscale;
in
{
  options = {
    dotfiles.tailscale = {
      ipv4 = lib.mkOption {
        type = lib.types.str;
        description = "Tailscale IPv4 address of this host.";
      };
      ipv6 = lib.mkOption {
        type = lib.types.str;
        description = "Tailscale IPv6 address of this host.";
      };
    };

    # every site is a subdomain under the wildcard certificate, served only over tailscale
    services.caddy.virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          config = {
            useACMEHost = lib.mkDefault domain;
            logFormat = lib.mkDefault null;
          };
        }
      );
    };
  };

  config = {
    sops.secrets."cloudflare/api-token" = { };

    security.acme = {
      acceptTerms = true;
      defaults.email = config.home-manager.users.lucas.programs.git.settings.user.email;
      certs.${domain} = {
        extraDomainNames = [ "*.${domain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets."cloudflare/api-token".path;
        group = "acme";
      };
    };

    users.users.caddy.extraGroups = [ "acme" ];
    services.caddy = {
      enable = true;
      openFirewall = false;
      globalConfig = ''
        default_bind ${tailscale.ipv4} [${tailscale.ipv6}]
        auto_https disable_redirects
        servers {
          protocols h1 h2
        }
      '';
    };

    systemd.services.caddy = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      # tailscaled can start before its addresses are assigned
      startLimitIntervalSec = lib.mkForce 0;
      serviceConfig.RestartPreventExitStatus = lib.mkForce "";
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
  };
}
