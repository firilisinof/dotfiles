{ lib, pkgs, ... }:

{
  sops.secrets."games/prowlarr-password" = { };
  services.prowlarr = {
    enable = true;
    dataDir = "/var/lib/prowlarr";
    openFirewall = false;
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
    ReadWritePaths = [ "/var/lib/prowlarr" ];
    InaccessiblePaths = [ "-/run/nscd" ];
    BindReadOnlyPaths = [
      "${pkgs.writeText "prowlarr-resolv.conf" ''
        nameserver 1.1.1.1
        nameserver 1.0.0.1
      ''}:/etc/resolv.conf"
    ];
  };
  services.caddy.virtualHosts."prowlarr.firilisinof.com".extraConfig = "reverse_proxy 127.0.0.1:9696";
  services.restic.backups.b2 = {
    stopUnits = [ "prowlarr.service" ];
    paths = [ "/var/lib/prowlarr" ];
    exclude = [
      "/var/lib/prowlarr/logs"
      "/var/lib/prowlarr/Backups"
      "/var/lib/prowlarr/UpdateLogs"
    ];
  };
}
