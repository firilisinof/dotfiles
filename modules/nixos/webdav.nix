{ config, ... }:

let
  cfg = config.services.webdav;
in
{
  sops.secrets."webdav/password" = { };
  sops.templates."webdav.env".content = ''
    WEBDAV_PASSWORD=${config.sops.placeholder."webdav/password"}
  '';

  services.webdav = {
    enable = true;
    environmentFile = config.sops.templates."webdav.env".path;
    settings = {
      address = "0.0.0.0";
      port = 8080;
      # zotero stores its files in a zotero directory under the given url
      directory = "/srv/webdav";
      permissions = "CRUD";
      users = [
        {
          username = "lucas";
          password = "{env}WEBDAV_PASSWORD";
        }
      ];
    };
  };

  systemd.tmpfiles.rules = [ "d ${cfg.settings.directory} 0750 ${cfg.user} ${cfg.group} - -" ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.settings.port ];
}
