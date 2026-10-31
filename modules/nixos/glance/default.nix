{ config, pkgs, ... }:

let
  cfg = config.services.glance;
  repositoryDirectory = "/run/glance-repositories";
  assets = pkgs.linkFarm "glance-assets" [
    {
      name = "custom.css";
      path = pkgs.writeText "glance-custom.css" ''
        .widget-type-server-stats .widget-header > div:has(.widget-beta-icon) {
          display: none;
        }
      '';
    }
    {
      name = "repositories.json";
      path = "${repositoryDirectory}/repositories.json";
    }
  ];
in
{
  services.glance = {
    enable = true;
    settings = {
      server = {
        host = "127.0.0.1";
        port = 8081;
        proxied = true;
        assets-path = "${assets}";
      };
      theme = {
        light = true;
        background-color = "0 0 100";
        primary-color = "0 0 20";
        custom-css-file = "/assets/custom.css";
      };
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                  timezones = [
                    {
                      timezone = "Europe/Paris";
                      label = "Paris";
                    }
                    {
                      timezone = "America/Sao_Paulo";
                      label = "São Paulo";
                    }
                  ];
                }
                {
                  type = "calendar";
                  first-day-of-week = "monday";
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {
                  type = "monitor";
                  title = "Services";
                  cache = "1m";
                  sites = [
                    {
                      title = "Kavita";
                      url = "https://read.firilisinof.com";
                      icon = "sh:kavita";
                    }
                    {
                      title = "Kanidm";
                      url = "https://auth.firilisinof.com";
                      check-url = "https://auth.firilisinof.com/status";
                      icon = "https://raw.githubusercontent.com/selfhst/icons/main/svg/kanidm.svg";
                    }
                    {
                      title = "WebDAV";
                      url = "https://dav.firilisinof.com";
                      icon = "mdi:folder-sync";
                      # an authentication challenge confirms the protected endpoint is reachable
                      alt-status-codes = [ 401 ];
                    }
                  ];
                }
                {
                  type = "server-stats";
                  servers = [
                    {
                      type = "local";
                      name = "pi5";
                      hide-swap = true;
                      hide-mountpoints-by-default = true;
                      mountpoints = {
                        "/" = {
                          name = "NVMe";
                          hide = false;
                        };
                        "/boot" = {
                          name = "SD card";
                          hide = false;
                        };
                      };
                    }
                  ];
                }
                {
                  type = "custom-api";
                  title = "Git Repositories";
                  cache = "1s";
                  url = "http://${cfg.settings.server.host}:${toString cfg.settings.server.port}/assets/repositories.json";
                  template = ''
                    <ul class="list list-gap-10">
                    {{ range .JSON.Array "repositories" }}
                      <li class="color-highlight">{{ .String "name" }}</li>
                    {{ else }}
                      <li class="color-subdue">No repositories yet.</li>
                    {{ end }}
                    </ul>
                  '';
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "weather";
                  location = "Grenoble, France";
                  units = "metric";
                  hour-format = "24h";
                }
              ];
            }
          ];
        }
      ];
    };
  };

  systemd.services.glance = {
    after = [ "glance-repositories.service" ];
    wants = [ "glance-repositories.service" ];
  };

  systemd.services.glance-repositories = {
    description = "Generate the Glance Git repository list";
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "lucas";
      Group = "users";
      ExecStart = "${pkgs.python3}/bin/python3 ${./repositories.py} /srv/git ${repositoryDirectory}/repositories.json";
      RuntimeDirectory = "glance-repositories";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = "yes";
      UMask = "0022";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.paths.glance-repositories = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/srv/git";
  };

  services.caddy.virtualHosts."home.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy ${cfg.settings.server.host}:${toString cfg.settings.server.port}";
  };
}
