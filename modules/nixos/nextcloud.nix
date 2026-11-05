{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nextcloud;
  hostname = "cloud.firilisinof.com";
  database = config.services.mysql.package;
  dumpDirectory = "/var/backup/nextcloud";
  disabledApps = [
    "activity"
    "circles"
    "comments"
    "contactsinteraction"
    "dashboard"
    "federatedfilesharing"
    "federation"
    "files_reminders"
    "files_sharing"
    "firstrunwizard"
    "nextcloud_announcements"
    "photos"
    "recommendations"
    "related_resources"
    "sharebymail"
    "support"
    "survey_client"
    "systemtags"
    "user_status"
    "weather_status"
  ];
in
{
  sops.secrets."nextcloud/admin-password" = { };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud35;
    hostName = hostname;
    home = "/srv/nextcloud";
    https = true;
    configureRedis = true;
    nginx.enableFastcgiRequestBuffering = true;
    database.createLocally = true;
    config.dbtype = "mysql";
    appstoreEnable = false;
    maxUploadSize = "16G";
    phpOptions = {
      memory_limit = lib.mkForce "512M";
      "opcache.interned_strings_buffer" = "16";
    };
    cli.memoryLimit = "512M";
    poolSettings = {
      pm = "ondemand";
      "pm.max_children" = 4;
      "pm.process_idle_timeout" = "60s";
      "pm.max_requests" = 500;
    };
    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      overwriteprotocol = "https";
      "overwrite.cli.url" = "https://${hostname}";
      defaultapp = "files";
      default_phone_region = "FR";
      default_timezone = config.time.timeZone;
      skeletondirectory = "";
      templatedirectory = "";
      maintenance_window_start = 2;
      mail_smtpmode = "null";
      log_type = "systemd";
    };
  };

  services.mysql.settings.mysqld = {
    skip-networking = true;
    transaction_isolation = "READ-COMMITTED";
    binlog_format = "ROW";
    innodb_buffer_pool_size = "128M";
  };

  services.nginx.virtualHosts.${hostname}.listen = [
    {
      addr = "127.0.0.1";
      port = 8086;
    }
  ];
  services.caddy.virtualHosts.${hostname}.extraConfig = "reverse_proxy 127.0.0.1:8086";

  systemd.services.nextcloud-setup = {
    serviceConfig.LoadCredential = [
      "admin-password:${config.sops.secrets."nextcloud/admin-password".path}"
    ];
    postStart = ''
      if ! nextcloud-occ user:info lucas > /dev/null 2>&1; then
        export OC_PASS="$(cat "$CREDENTIALS_DIRECTORY/admin-password")"
        nextcloud-occ user:add --password-from-env --display-name Lucas lucas
        unset OC_PASS
      fi
      nextcloud-occ group:adduser admin lucas
      for app in ${lib.escapeShellArgs disabledApps}; do
        if [ -d "${cfg.package}/apps/$app" ]; then
          nextcloud-occ app:disable "$app"
        fi
      done
    '';
  };

  systemd.tmpfiles.rules = [ "d ${dumpDirectory} 0700 root root - -" ];

  services.restic.backups.b2 = {
    paths = [ dumpDirectory ];
    stopUnits = [
      "nextcloud-cron.timer"
      "nextcloud-cron.service"
      "phpfpm-nextcloud.service"
    ];
  };
  systemd.services.restic-backups-b2.preStart = lib.mkAfter ''
    dump=${dumpDirectory}/nextcloud.sql
    tmp="$dump.tmp"
    rm -f "$dump" "$tmp"
    umask 077
    trap 'rm -f "$tmp"' EXIT
    ${lib.getExe' database "mariadb-dump"} \
      --single-transaction --quick --routines --events --triggers nextcloud > "$tmp"
    test -s "$tmp"
    mv "$tmp" "$dump"
    trap - EXIT
  '';
}
