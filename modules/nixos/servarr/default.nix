{ lib, pkgs, ... }:

let
  apps = {
    prowlarr = 9696;
    sonarr = 8989;
    radarr = 7878;
  };
in
{
  imports = lib.mapAttrsToList (name: port: {
    services.${name} = {
      enable = true;
      dataDir = "/var/lib/${name}";
      openFirewall = false;
      settings.server = {
        inherit port;
        bindaddress = "127.0.0.1";
      };
    };
    systemd.services.${name}.serviceConfig = {
      UMask = lib.mkForce "0007";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/${name}" ] ++ lib.optional (name != "prowlarr") "/srv/media";
    };
  }) apps;

  services.sonarr.group = "media";
  services.radarr.group = "media";
  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
  };
  users.groups.prowlarr = { };

  sops.secrets = lib.mapAttrs' (name: _: lib.nameValuePair "${name}/admin-password" { }) apps;

  systemd.tmpfiles.rules = [
    "d /var/lib/sonarr 0700 sonarr media - -"
    "d /srv/media/downloads/sonarr 2770 qbittorrent media - -"
    "d /srv/media/downloads/radarr 2770 qbittorrent media - -"
  ];

  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "prowlarr";
    Group = "prowlarr";
    StateDirectoryMode = "0700";
  };

  systemd.services.servarr-setup = {
    description = "Connect media managers to Prowlarr and qBittorrent";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "caddy.service"
      "qbittorrent.service"
    ]
    ++ map (name: "${name}.service") (builtins.attrNames apps);
    after = [
      "network-online.target"
      "caddy.service"
      "qbittorrent.service"
    ]
    ++ map (name: "${name}.service") (builtins.attrNames apps);
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./setup.py}";
      UMask = "0077";
      TimeoutStartSec = "5min";
    };
  };

  services.caddy.virtualHosts = lib.mapAttrs' (
    name: port:
    lib.nameValuePair "${name}.firilisinof.com" {
      useACMEHost = "firilisinof.com";
      logFormat = null;
      extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
    }
  ) apps;

  services.restic.backups.b2 = {
    paths = map (name: "/var/lib/${name}") (builtins.attrNames apps);
    exclude = lib.concatMap (name: [
      "/var/lib/${name}/*.db*"
      "/var/lib/${name}/logs"
      "/var/lib/${name}/Backups"
      "/var/lib/${name}/UpdateLogs"
    ]) (builtins.attrNames apps);
    sqlite = lib.mapAttrs (name: _: {
      path = "/var/lib/${name}/${name}.db";
      user = name;
    }) apps;
  };
}
