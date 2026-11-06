{ config, pkgs, ... }:

let
  cfg = config.services.glance;
  assets = pkgs.writeTextDir "custom.css" ''
    .widget-type-server-stats .widget-header > div:has(.widget-beta-icon) {
      display: none;
    }
  '';
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
              size = "full";
              widgets = [
                {
                  type = "monitor";
                  title = "Services";
                  cache = "1m";
                  sites = [
                    {
                      title = "Nextcloud";
                      url = "https://cloud.firilisinof.com";
                      check-url = "https://cloud.firilisinof.com/status.php";
                      icon = "sh:nextcloud";
                    }
                    {
                      title = "Kavita";
                      url = "https://read.firilisinof.com";
                      icon = "sh:kavita";
                    }
                    {
                      title = "Find Books";
                      url = "https://shelfmark.firilisinof.com";
                      icon = "mdi:book-search";
                    }
                    {
                      title = "Kapowarr";
                      url = "https://kapowarr.firilisinof.com";
                      icon = "mdi:book-open-page-variant";
                    }
                    {
                      title = "Suwayomi";
                      url = "https://suwayomi.firilisinof.com";
                      icon = "mdi:book-open";
                      alt-status-codes = [ 401 ];
                    }
                    {
                      title = "MetaKavita";
                      url = "https://metakavita.firilisinof.com";
                      check-url = "https://metakavita.firilisinof.com/healthz";
                      icon = "mdi:book-edit";
                    }
                    {
                      title = "YouTube Archive";
                      url = "https://archive.firilisinof.com";
                      icon = "mdi:youtube";
                      alt-status-codes = [ 401 ];
                    }
                    {
                      title = "qBittorrent";
                      url = "https://torrents.firilisinof.com";
                      icon = "sh:qbittorrent";
                    }
                    {
                      title = "Forgejo";
                      url = "https://git.firilisinof.com";
                      check-url = "https://git.firilisinof.com/api/healthz";
                      icon = "sh:forgejo";
                    }
                    {
                      title = "Kanidm";
                      url = "https://auth.firilisinof.com";
                      check-url = "https://auth.firilisinof.com/status";
                      icon = "https://raw.githubusercontent.com/selfhst/icons/main/svg/kanidm.svg";
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
              ];
            }
          ];
        }
      ];
    };
  };

  services.caddy.virtualHosts."home.firilisinof.com".extraConfig =
    "reverse_proxy ${cfg.settings.server.host}:${toString cfg.settings.server.port}";
}
