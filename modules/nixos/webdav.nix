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
      address = "127.0.0.1";
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

  services.caddy.virtualHosts."dav.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy ${cfg.settings.address}:${toString cfg.settings.port}";
  };
}
