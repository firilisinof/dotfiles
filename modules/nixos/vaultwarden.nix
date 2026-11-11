_:

let
  hostname = "vault.firilisinof.com";
  dataDirectory = "/var/lib/vaultwarden";
in
{
  services.vaultwarden = {
    enable = true;
    domain = hostname;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = false;
      ORG_CREATION_USERS = "none";
      IP_HEADER = "X-Forwarded-For";
      EXPERIMENTAL_CLIENT_FEATURE_FLAGS = "ssh-agent-v2,biometrics-sdk-ipc";
    };
  };

  services.caddy.virtualHosts.${hostname}.extraConfig = "reverse_proxy 127.0.0.1:8222";

  services.restic.backups.b2 = {
    paths = [ dataDirectory ];
    exclude = [
      "${dataDirectory}/db.sqlite3*"
      "${dataDirectory}/icon_cache"
      "${dataDirectory}/tmp"
    ];
    sqlite.vaultwarden = {
      path = "${dataDirectory}/db.sqlite3";
      user = "vaultwarden";
    };
  };
}
