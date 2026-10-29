{ config, lib, ... }:

{
  sops.secrets."cloudflare/api-token" = { };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.home-manager.users.lucas.programs.git.settings.user.email;
    certs."firilisinof.com" = {
      extraDomainNames = [ "*.firilisinof.com" ];
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
      default_bind 100.74.192.104 [fd7a:115c:a1e0::c37:c069]
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
}
