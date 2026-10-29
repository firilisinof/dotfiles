{
  config,
  ...
}:

let
  cfg = config.services.kavita;
in
{
  sops.secrets."kavita/token-key".restartUnits = [ "kavita.service" ];
  sops.secrets."kavita/oidc-secret".restartUnits = [ "kavita.service" ];

  services.kavita = {
    enable = true;
    dataDir = "/srv/kavita";
    credentials = {
      token_key = config.sops.secrets."kavita/token-key".path;
      oidc_secret = config.sops.secrets."kavita/oidc-secret".path;
    };
    settings = {
      IpAddresses = "127.0.0.1";
      Port = 5000;
      TokenKey = "@token_key@";
      AllowIFraming = false;
      OpenIdConnectSettings = {
        Authority = "${config.services.kanidm.server.settings.origin}/oauth2/openid/kavita";
        ClientId = "kavita";
        Secret = "@oidc_secret@";
      };
    };
  };

  systemd.tmpfiles.rules = [ "d /srv/books 0750 ${cfg.user} ${cfg.user} - -" ];

  systemd.services.kavita = {
    after = [ "kanidm.service" ];
    serviceConfig.UMask = "0027";
  };

  services.restic.backups.b2 = {
    exclude = map (path: "${cfg.dataDir}/config/${path}") [
      "kavita.db*"
      "appsettings.json"
      "backups"
      "cache"
      "cache-long"
      "cache.db*"
      "temp"
      "logs"
    ];
    sqlite.kavita = {
      path = "${cfg.dataDir}/config/kavita.db";
      inherit (cfg) user;
    };
  };

  services.caddy.virtualHosts."read.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy ${cfg.settings.IpAddresses}:${toString cfg.settings.Port}";
  };
}
