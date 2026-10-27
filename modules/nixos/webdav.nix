{ config, lib, ... }:

let
  cfg = config.services.webdav;
  tailscale = lib.getExe config.services.tailscale.package;
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

  # zotero on ios requires https for non-local servers
  systemd.services.tailscale-serve-webdav = {
    after = [
      "tailscaled.service"
      "webdav.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # tailscaled may not be connected yet at boot
      Restart = "on-failure";
      RestartSec = 10;
      ExecStart = "${tailscale} serve --bg --https=443 http://${cfg.settings.address}:${toString cfg.settings.port}";
      # tailscaled persists serve config, so remove it when the unit stops
      ExecStop = "${tailscale} serve --https=443 off";
    };
  };
}
