{ ... }:

let
  dataDir = "/srv/anytype";
  uid = 800;
  service = "podman-anytype.service";
in
{
  users.users.anytype = {
    inherit uid;
    isSystemUser = true;
    group = "anytype";
  };
  users.groups.anytype.gid = uid;

  systemd.tmpfiles.rules = [ "d ${dataDir} 0700 anytype anytype - -" ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers.anytype = {
      # all-in-one image 1.7.0-2026-10-12
      image = "ghcr.io/grishy/any-sync-bundle@sha256:8c0a00d7ecf78ccc636743ed83153c593792238f49a37bf6cf7b9b5c1ea557db";
      user = "${toString uid}:${toString uid}";
      # published ports bypass the nixos firewall, and mongodb and redis bind only loopback
      networks = [ "host" ];
      volumes = [ "${dataDir}:/data" ];
      # read only on the first start, then bundle-config.yml owns the address
      environment.ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS = "100.74.192.104";
      extraOptions = [ "--stop-timeout=120" ];
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 33010 ];
    allowedUDPPorts = [ 33020 ];
  };

  # upstream supports backups only after a clean stop
  services.restic.backups.b2 = {
    backupPrepareCommand = "systemctl stop ${service}";
    backupCleanupCommand = "systemctl start ${service}";
    exclude = [ "${dataDir}/mongo/diagnostic.data" ];
  };
}
