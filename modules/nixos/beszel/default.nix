{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.beszel;
  email = config.home-manager.users.lucas.programs.git.settings.user.email;
  hubUrl = "http://${cfg.hub.host}:${toString cfg.hub.port}";
  monitors = pkgs.writeText "beszel-monitors.json" (
    builtins.toJSON [
      { target = "https://cloud.firilisinof.com/status.php"; }
      { target = "https://read.firilisinof.com"; }
      { target = "https://shelfmark.firilisinof.com"; }
      { target = "https://kapowarr.firilisinof.com"; }
      {
        target = "suwayomi.firilisinof.com";
        protocol = "tcp";
        port = 443;
      }
      {
        target = "archive.firilisinof.com";
        protocol = "tcp";
        port = 443;
      }
      { target = "https://torrents.firilisinof.com"; }
      { target = "https://games.firilisinof.com/api/heartbeat"; }
      { target = "https://romarr.firilisinof.com/api/health"; }
      { target = "https://game-requests.firilisinof.com/api/health"; }
      { target = "https://prowlarr.firilisinof.com"; }
      { target = "https://git.firilisinof.com/api/healthz"; }
      { target = "https://auth.firilisinof.com/status"; }
    ]
  );
in
{
  services.beszel = {
    hub = {
      enable = true;
      environment = {
        APP_URL = "https://home.firilisinof.com";
        AUTO_LOGIN = email;
      };
    };
    agent = {
      enable = true;
      smartmon = {
        enable = true;
        deviceAllow = [
          "/dev/nvme0"
          "/dev/nvme0n1"
        ];
      };
      extraPath = [
        pkgs.systemd
        pkgs.iw
      ];
      environment = {
        LISTEN = "127.0.0.1:45876";
        KEY_FILE = "${cfg.agent.dataDir}/hub-key.pub";
        FILESYSTEM = "/";
        EXTRA_FILESYSTEMS = "/boot";
        PRIMARY_SENSOR = "cpu_thermal";
        SMART_DEVICES = "/dev/nvme0n1:nvme";
        SKIP_GPU = true;
        DOCKER_HOST = "";
        SERVICE_PATTERNS = lib.concatStringsSep "," [
          "beszel*"
          "caddy*"
          "forgejo*"
          "kanidm*"
          "mysql*"
          "nextcloud*"
          "nginx*"
          "phpfpm-nextcloud*"
          "podman-*"
          "prowlarr*"
          "qbittorrent*"
          "reading-*"
          "redis-nextcloud*"
          "restic-*"
          "sshd*"
          "suwayomi*"
          "tailscaled*"
          "wifi-watchdog*"
        ];
      };
    };
  };

  systemd.services.beszel-agent = {
    requires = [ "beszel-hub.service" ];
    after = [ "beszel-hub.service" ];
    preStart = ''
      ${lib.getExe pkgs.python3} ${./setup.py} ${hubUrl} ${lib.escapeShellArg email} ${config.networking.hostName} ${monitors} ${cfg.agent.environment.KEY_FILE}
    '';
  };

  # a static owner keeps the state directory directly accessible to restic
  users.groups.beszel-hub = { };
  users.users.beszel-hub = {
    isSystemUser = true;
    group = "beszel-hub";
  };
  systemd.services.beszel-hub.serviceConfig.DynamicUser = lib.mkForce false;

  services.restic.backups.b2 = {
    paths = [ cfg.hub.dataDir ];
    exclude = [
      "${cfg.hub.dataDir}/beszel_data/data.db*"
      "${cfg.hub.dataDir}/beszel_data/auxiliary.db*"
    ];
    sqlite = {
      beszel = {
        path = "${cfg.hub.dataDir}/beszel_data/data.db";
        user = "beszel-hub";
      };
      beszel-auxiliary = {
        path = "${cfg.hub.dataDir}/beszel_data/auxiliary.db";
        user = "beszel-hub";
      };
    };
  };

  services.caddy.virtualHosts."home.firilisinof.com".extraConfig =
    "reverse_proxy ${cfg.hub.host}:${toString cfg.hub.port}";
}
