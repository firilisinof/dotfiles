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
                  type = "bookmarks";
                  groups = [
                    {
                      links = [
                        {
                          title = "Kavita";
                          url = "https://read.firilisinof.com";
                        }
                        {
                          title = "Kanidm";
                          url = "https://auth.firilisinof.com";
                        }
                        {
                          title = "WebDAV";
                          url = "https://dav.firilisinof.com";
                        }
                      ];
                    }
                  ];
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
