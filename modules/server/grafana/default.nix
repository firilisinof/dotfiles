{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking) domain;
  hostname = "home.${domain}";
  inherit (config.services) grafana prometheus;
  monitors = config.dotfiles.monitors;
  hosts = lib.unique (
    lib.attrNames config.services.caddy.virtualHosts
    ++ lib.attrNames config.dotfiles.tunnel.ingress
    ++ [ "www.${domain}" ]
  );
  link = host: "https://${host}" + lib.optionalString (host == "mcp.${domain}") "/mcp";
  serviceNames = {
    games = "Games";
    cloud = "Files";
    torrents = "Torrents";
    auth = "Identity";
    home = "Pi dashboard";
    mcp = "MCP";
    vault = "Passwords";
    www = "Website";
    yt = "YouTube archive";
  };
  favorites = [
    "games"
    "cloud"
    "torrents"
  ];
  inventory = pkgs.writeText "services.prom" (
    lib.concatMapStrings (
      host:
      let
        subdomain = lib.removeSuffix ".${domain}" host;
        name = serviceNames.${subdomain} or host;
        priority = lib.lists.findFirstIndex (
          favorite: favorite == subdomain
        ) (lib.length favorites) favorites;
        labels = {
          url = link host;
          service = name;
          sort_key = "${toString priority} ${name}";
          probed = lib.boolToString (monitors ? ${host});
        };
      in
      "pi5_service_info{${
        lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}=${builtins.toJSON v}") labels)
      }} 1\n"
    ) hosts
  );
  metricDirectory = "/var/lib/pi5-metrics";
  blackbox = prometheus.exporters.blackbox;
  node = prometheus.exporters.node;
  dashboard = pkgs.writeText "pi5-dashboard.json" (builtins.toJSON (import ./dashboard.nix));
  seedDirectory = "${grafana.dataDir}/dashboards";
in
{
  imports = [
    ./alerts.nix
    ./identity.nix
  ];

  options.dotfiles.monitors = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.strMatching "/.*";
            default = "/";
            description = "HTTPS availability path.";
          };
          tcpPort = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "Probe this TCP port on the hostname.";
          };
        };
      }
    );
    default = { };
    description = "Service availability checks keyed by hostname.";
  };

  config = {
    systemd.tmpfiles.rules = [
      "d ${metricDirectory} 0755 root root -"
      "L+ ${metricDirectory}/services.prom - - - - ${inventory}"
      # its creation time starts the overdue clock until the first successful backup
      "f ${metricDirectory}/restic-b2-start.prom 0644 root root -"
    ];

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      globalConfig.scrape_interval = "1m";
      exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "cpu"
          "filesystem"
          "meminfo"
          "hwmon"
          "textfile"
        ];
        extraFlags = [
          "--collector.disable-defaults"
          "--collector.textfile.directory=${metricDirectory}"
        ];
      };
      exporters.blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        configFile = pkgs.writeText "blackbox.json" (
          builtins.toJSON {
            modules = {
              http = {
                prober = "http";
                http.preferred_ip_protocol = "ip4";
              };
              tcp = {
                prober = "tcp";
                tcp.preferred_ip_protocol = "ip4";
              };
            };
          }
        );
      };
      scrapeConfigs = [
        {
          job_name = "pi5";
          static_configs = [ { targets = [ "127.0.0.1:${toString node.port}" ]; } ];
        }
        {
          job_name = "services";
          metrics_path = "/probe";
          static_configs = lib.mapAttrsToList (host: probe: {
            targets = [
              (
                if probe.tcpPort == null then
                  "https://${host}${probe.path}"
                else
                  "${host}:${toString probe.tcpPort}"
              )
            ];
            labels = {
              url = link host;
              __param_module = if probe.tcpPort == null then "http" else "tcp";
            };
          }) monitors;
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:${toString blackbox.port}";
            }
          ];
        }
      ];
    };

    services.grafana = {
      enable = true;
      declarativePlugins = [ pkgs.grafanaPlugins.prometheus ];
      settings.users.default_theme = "light";
      settings.plugins.preinstall_disabled = true;
      settings.server = {
        domain = hostname;
        root_url = "https://${hostname}/";
        http_addr = "127.0.0.1";
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString prometheus.port}";
            isDefault = true;
            jsonData.timeInterval = "1m";
          }
        ];
        dashboards.settings.providers = [
          {
            name = "Home";
            options.path = seedDirectory;
            allowUiUpdates = true;
            disableDeletion = true;
          }
        ];
      };
    };

    # withdraw the seed after the first import so browser edits survive restarts
    systemd.services.grafana = {
      preStart = ''
        mkdir -p ${seedDirectory}
        if [ ! -e ${seedDirectory}/.imported ]; then
          install -m 0644 ${dashboard} ${seedDirectory}/pi5.json.tmp
          mv ${seedDirectory}/pi5.json.tmp ${seedDirectory}/pi5.json
        fi
      '';
      postStart = ''
        if [ -f ${seedDirectory}/pi5.json ]; then
          ${lib.getExe pkgs.curl} --fail --silent --show-error --retry 40 --retry-all-errors \
            --retry-delay 1 --max-time 3 --output /dev/null \
            http://127.0.0.1:${toString grafana.settings.server.http_port}/api/dashboards/uid/pi5
          mv ${seedDirectory}/pi5.json ${seedDirectory}/.imported
        fi
      '';
    };
    services.caddy.virtualHosts.${hostname}.extraConfig = ''
      redir / /d/pi5/pi5 302
      reverse_proxy 127.0.0.1:${toString grafana.settings.server.http_port}
    '';

    services.restic.backups.b2 = {
      sqlite.grafana = {
        path = grafana.settings.database.path;
        user = "grafana";
      };
      paths = [
        seedDirectory
        metricDirectory
      ];
    };
  };
}
