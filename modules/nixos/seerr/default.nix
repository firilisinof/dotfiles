{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.seerr;
in
{
  sops.secrets."seerr/api-key" = {
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [
      "seerr.service"
      "jellyfin.service"
    ];
  };
  sops.templates."seerr.env".content = ''
    API_KEY=${config.sops.placeholder."seerr/api-key"}
  '';

  services.seerr = {
    enable = true;
    stateRevision = 1;
    configDir = "/var/lib/seerr";
    port = 5055;
    openFirewall = false;
  };

  users.users.seerr = {
    isSystemUser = true;
    group = "seerr";
  };
  users.groups.seerr = { };

  # the sqlite copy for the backup runs as this user outside the service, which a dynamic user cannot do
  systemd.services.seerr = {
    environment = {
      HOST = "127.0.0.1";
      LOG_LEVEL = "info";
      NEXT_TELEMETRY_DISABLED = "1";
    };
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "seerr";
      Group = "seerr";
      StateDirectoryMode = "0700";
      UMask = "0077";
      EnvironmentFile = config.sops.templates."seerr.env".path;
    };
  };

  systemd.services.seerr-setup = {
    description = "Connect Seerr to Jellyfin and media managers";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "seerr.service"
      "jellyfin.service"
      "servarr-setup.service"
    ];
    after = [
      "network-online.target"
      "seerr.service"
      "jellyfin.service"
      "servarr-setup.service"
    ];
    path = [ pkgs.systemd ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./setup.py}";
      UMask = "0077";
      TimeoutStartSec = "5min";
    };
  };

  services.caddy.virtualHosts."requests.firilisinof.com".extraConfig =
    "reverse_proxy 127.0.0.1:${toString cfg.port}";

  services.restic.backups.b2 = {
    paths = [ cfg.configDir ];
    exclude = [
      "${cfg.configDir}/db/*.sqlite3*"
      "${cfg.configDir}/logs"
      "${cfg.configDir}/cache"
    ];
    sqlite.seerr = {
      path = "${cfg.configDir}/db/db.sqlite3";
      user = "seerr";
    };
  };
}
