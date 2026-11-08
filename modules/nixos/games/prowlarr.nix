{
  config,
  lib,
  pkgs,
  ...
}:

{
  virtualisation.oci-containers.containers.byparr = {
    image = "ghcr.io/thephaseless/byparr@sha256:1d29d188fcfb72ba18e32d00035757a286c637d3aeec6ebee68b14e6a316345e";
    ports = [ "127.0.0.1:8191:8191" ];
    environment.TZ = config.time.timeZone;
    extraOptions = [
      "--shm-size=1g"
      "--tmpfs=/tmp:rw,exec,mode=1777,size=1g"
      "--memory=2g"
      "--cpus=2"
      "--dns=1.1.1.1"
      "--dns=1.0.0.1"
    ];
  };
  systemd.services.games-setup = {
    wants = [ "podman-byparr.service" ];
    after = [ "podman-byparr.service" ];
  };
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
