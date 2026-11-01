{
  config,
  lib,
  pkgs,
  ...
}:

let
  dataDir = "/var/lib/bazarr";
  credentialsDir = "${dataDir}/credentials";
  python = lib.getExe pkgs.python3;
in
{
  services.bazarr = {
    enable = true;
    inherit dataDir;
    group = "media";
    openFirewall = false;
    settings = {
      general = {
        ip = "127.0.0.1";
        port = 6767;
        concurrent_jobs = 1;
        multithreading = false;
        use_embedded_subs = true;
        ignore_pgs_subs = true;
        ignore_vobsub_subs = true;
        use_whisper_fallback = false;
        use_whisper_fallback_series = false;
        use_sonarr = true;
        use_radarr = true;
      };
      sonarr = {
        ip = "127.0.0.1";
        port = 8989;
        ssl = false;
        only_monitored = false;
        sync_only_monitored_series = false;
        sync_only_monitored_episodes = false;
        apikey._secret = "${credentialsDir}/sonarr-api-key";
        series_sync_on_live = false;
      };
      radarr = {
        ip = "127.0.0.1";
        port = 7878;
        ssl = false;
        only_monitored = false;
        sync_only_monitored_movies = false;
        apikey._secret = "${credentialsDir}/radarr-api-key";
        movies_sync_on_live = false;
      };
      subsync.use_subsync = false;
      auth = {
        type = "form";
        username = "lucas";
        apikey._secret = "${credentialsDir}/bazarr-api-key";
        password._secret = "${credentialsDir}/password-hash";
      };
    };
  };

  systemd.services.bazarr-credentials = {
    description = "Prepare private Bazarr credentials";
    wantedBy = [ "multi-user.target" ];
    before = [ "bazarr.service" ];
    after = [
      "sonarr.service"
      "radarr.service"
    ];
    requires = [
      "sonarr.service"
      "radarr.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
      TimeoutStartSec = "3min";
      ExecStart = "${python} ${./subtitle-setup.py} --prepare-credentials";
    };
  };

  systemd.services.bazarr = {
    requires = [ "bazarr-credentials.service" ];
    after = [ "bazarr-credentials.service" ];
    serviceConfig.UMask = lib.mkForce "0007";
  };

  systemd.services.bazarr-setup = {
    description = "Configure Bazarr subtitle profiles and media manager connections";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "bazarr.service"
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    requires = [
      "bazarr.service"
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
      TimeoutStartSec = "10min";
      ExecStart = "${python} ${./subtitle-setup.py}";
    };
  };

  services.caddy.virtualHosts."bazarr.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy 127.0.0.1:6767";
  };

  services.restic.backups.b2 = {
    paths = [ dataDir ];
    exclude = [
      "${credentialsDir}"
      "${dataDir}/db/*.db*"
      "${dataDir}/db/*.sqlite3*"
      "${dataDir}/logs"
      "${dataDir}/cache"
    ];
    sqlite.bazarr = {
      path = "${dataDir}/db/bazarr.db";
      user = "bazarr";
    };
  };
}
