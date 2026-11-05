{ config, pkgs, ... }:

let
  dataDir = "/srv/metakavita";
  image = "ghcr.io/raukorim-bot/metakavita@sha256:03492f964a4fba6ad76860ad36d94d828df37b5da8daff8f3953744136a6bd40";
in
{
  users.groups.metakavita.gid = 806;
  users.users.metakavita = {
    isSystemUser = true;
    uid = 806;
    group = "metakavita";
  };

  sops.secrets."reading/metakavita-password" = { };
  systemd.tmpfiles.rules = [ "d ${dataDir} 0700 metakavita metakavita - -" ];

  virtualisation.oci-containers.containers.metakavita = {
    inherit image;
    autoRemoveOnStop = false;
    environment = {
      PUID = "806";
      PGID = "806";
      ADMIN_USERNAME = "lucas";
      TRUSTED_PROXY_COUNT = "1";
      SESSION_COOKIE_SECURE = "1";
      CORS_ALLOWED_ORIGINS = "https://metakavita.firilisinof.com";
      TZ = config.time.timeZone;
    };
    environmentFiles = [ "/run/metakavita/credentials.env" ];
    volumes = [ "${dataDir}:/app/data" ];
    cmd = [
      "gunicorn"
      "--worker-class"
      "eventlet"
      "-w"
      "1"
      "--bind"
      "127.0.0.1:5010"
      "app:app"
    ];
    extraOptions = [
      "--network=host"
      "--umask=0077"
      "--dns=1.1.1.1"
    ];
  };

  systemd.services.podman-metakavita = {
    after = [ "kavita.service" ];
    wants = [ "kavita.service" ];
    preStart = "${pkgs.python3}/bin/python3 ${./prepare.py} metakavita";
    serviceConfig = {
      RuntimeDirectory = "metakavita";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  services.caddy.virtualHosts."metakavita.firilisinof.com".extraConfig =
    "reverse_proxy 127.0.0.1:5010";

  services.restic.backups.b2 = {
    stopUnits = [ "podman-metakavita.service" ];
    exclude = [
      "${dataDir}/cache.db*"
      "${dataDir}/metakavita.log*"
    ];
    sqlite.metakavita = {
      path = "${dataDir}/cache.db";
      user = "metakavita";
    };
  };
}
