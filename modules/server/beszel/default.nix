{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.beszel;
  email = config.home-manager.users.lucas.programs.git.settings.user.email;
  hostname = "home.${config.networking.domain}";
  hubUrl = "http://${cfg.hub.host}:${toString cfg.hub.port}";
  monitors = pkgs.writeText "beszel-monitors.json" (builtins.toJSON config.dotfiles.monitors);
in
{
  options.dotfiles.monitors = lib.mkOption {
    type = lib.types.listOf (lib.types.attrsOf (lib.types.either lib.types.str lib.types.int));
    default = [ ];
    description = "Availability probes run by Beszel. Each needs a target, and defaults to an HTTP check every minute.";
  };

  config = {
    services.beszel = {
      hub = {
        enable = true;
        environment = {
          APP_URL = "https://${hostname}";
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
            "redis-nextcloud*"
            "restic-*"
            "sshd*"
            "tailscaled*"
            "vaultwarden*"
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

    services.caddy.virtualHosts.${hostname}.extraConfig =
      "reverse_proxy ${cfg.hub.host}:${toString cfg.hub.port}";
  };
}
