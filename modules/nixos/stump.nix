{ config, ... }:

let
  dataDir = "/srv/stump";
  image = "docker.io/aaronleopold/stump@sha256:0ca58bb8562e4f173e64b4472bb85dcb9e02ed73fb73c828bc3862e9a17f5add";
in
{
  users.users.stump = {
    isSystemUser = true;
    uid = 809;
    group = "reading";
  };

  sops.secrets."stump/oidc-secret".restartUnits = [ "podman-stump.service" ];
  sops.templates."stump.env".content = ''
    STUMP_OIDC_CLIENT_SECRET=${config.sops.placeholder."stump/oidc-secret"}
  '';

  systemd.tmpfiles.rules = [ "d ${dataDir} 0700 stump reading - -" ];

  virtualisation.oci-containers.containers.stump = {
    inherit image;
    autoRemoveOnStop = false;
    user = "809:803";
    environment = {
      STUMP_CONFIG_DIR = "/config";
      STUMP_IP = "127.0.0.1";
      STUMP_ENABLE_UPLOAD = "true";
      STUMP_MAX_FILE_UPLOAD_SIZE = "1073741824";
      STUMP_ALLOWED_ORIGINS = "https://read.firilisinof.com";
      STUMP_TRUST_PROXY_HEADERS = "true";
      STUMP_OIDC_ENABLED = "true";
      STUMP_OIDC_ISSUER_URL = "${config.services.kanidm.server.settings.origin}/oauth2/openid/stump";
      STUMP_OIDC_CLIENT_ID = "stump";
      STUMP_OIDC_ALLOW_REGISTRATION = "true";
      STUMP_OIDC_DISABLE_LOCAL_AUTH = "true";
      TZ = config.time.timeZone;
    };
    environmentFiles = [ config.sops.templates."stump.env".path ];
    volumes = [
      "${dataDir}:/config"
      "/srv/reading:/srv/reading"
    ];
    extraOptions = [
      "--entrypoint=/app/stump"
      "--network=host"
      "--umask=0007"
      "--dns=1.1.1.1"
    ];
  };

  systemd.services.podman-stump = {
    after = [ "kanidm.service" ];
    wants = [ "kanidm.service" ];
  };

  services.caddy.virtualHosts."read.firilisinof.com".extraConfig = "reverse_proxy 127.0.0.1:10801";

  services.restic.backups.b2.stopUnits = [ "podman-stump.service" ];
}
