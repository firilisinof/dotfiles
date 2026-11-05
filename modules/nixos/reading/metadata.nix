{ config, pkgs, ... }:

let
  dataDir = "/srv/metakavita";
  image = "ghcr.io/raukorim-bot/metakavita@sha256:03492f964a4fba6ad76860ad36d94d828df37b5da8daff8f3953744136a6bd40";
  source = pkgs.fetchFromGitHub {
    owner = "raukorim-bot";
    repo = "MetaKavita";
    rev = "b02b65ead0c51fa194a2e819e450d2d414a0256d";
    hash = "sha256-scwZ28i1WwJxqVFLg+zvwv2st3FKxmhaIQTWSIIR5+Q=";
  };
  volumeMatching =
    pkgs.runCommand "metakavita-volume-matching"
      {
        nativeBuildInputs = [
          pkgs.patch
          pkgs.python3
        ];
      }
      ''
        cp -R ${source} source
        chmod -R u+w source
        cd source
        python -c "from pathlib import Path; p = Path('kavita_api.py'); p.write_text(p.read_text())"
        patch -p1 < ${./metakavita-manga-volumes.patch}
        python ${./test_metadata.py} services/volume_enrichment/matching.py
        python -c "import ast; from pathlib import Path; ast.parse(Path('kavita_api.py').read_text())"
        mkdir "$out"
        cp services/volume_enrichment/{matching,job,plan}.py "$out/"
        cp kavita_api.py "$out/"
      '';
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
    volumes = [
      "${dataDir}:/app/data"
      "${volumeMatching}/matching.py:/app/services/volume_enrichment/matching.py:ro"
      "${volumeMatching}/job.py:/app/services/volume_enrichment/job.py:ro"
      "${volumeMatching}/plan.py:/app/services/volume_enrichment/plan.py:ro"
      "${volumeMatching}/kavita_api.py:/app/kavita_api.py:ro"
    ];
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
