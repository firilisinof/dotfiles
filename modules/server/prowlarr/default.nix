{
  config,
  lib,
  pkgs,
  ...
}:

let
  hostname = "prowlarr.${config.networking.domain}";
  dataDir = "/var/lib/prowlarr";
in
{
  sops.secrets."prowlarr/password" = { };
  sops.secrets."prowlarr/api-key" = { };
  # without this the key would exist only in the generated config.xml
  sops.templates."prowlarr.env".content = ''
    PROWLARR__AUTH__APIKEY=${config.sops.placeholder."prowlarr/api-key"}
  '';

  services.prowlarr = {
    enable = true;
    inherit dataDir;
    openFirewall = false;
    environmentFiles = [ config.sops.templates."prowlarr.env".path ];
    settings.server = {
      port = 9696;
      bindaddress = "127.0.0.1";
    };
  };
  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
  };
  users.groups.prowlarr = { };
  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "prowlarr";
    Group = "prowlarr";
    StateDirectoryMode = "0700";
    UMask = "0077";
    PrivateTmp = true;
    ProtectSystem = "strict";
    ReadWritePaths = [ dataDir ];
    InaccessiblePaths = [ "-/run/nscd" ];
    BindReadOnlyPaths = [
      "${pkgs.writeText "prowlarr-resolv.conf" ''
        nameserver 1.1.1.1
        nameserver 1.0.0.1
      ''}:/etc/resolv.conf"
    ];
  };

  services.caddy.virtualHosts.${hostname}.extraConfig = "reverse_proxy 127.0.0.1:9696";

  dotfiles.monitors = [ { target = "https://${hostname}"; } ];

  services.restic.backups.b2 = {
    stopUnits = [ "prowlarr.service" ];
    paths = [ dataDir ];
    exclude = [
      "${dataDir}/logs"
      "${dataDir}/Backups"
      "${dataDir}/UpdateLogs"
    ];
  };
}
