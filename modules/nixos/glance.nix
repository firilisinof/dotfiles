{ config, ... }:

let
  cfg = config.services.glance;
in
{
  services.glance = {
    enable = true;
    settings = {
      server = {
        host = "127.0.0.1";
        port = 8081;
        proxied = true;
      };
      theme = {
        light = true;
        background-color = "0 0 100";
        primary-color = "0 0 20";
      };
      pages = [
        {
          name = "Home";
          columns = [
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
                      icon = "sh:kanidm";
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
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "calendar";
                  first-day-of-week = "monday";
                }
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

  services.caddy.virtualHosts."firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy ${cfg.settings.server.host}:${toString cfg.settings.server.port}";
  };
}
