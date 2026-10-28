{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kanidm;
  hostname = "pi5.tail0a1230.ts.net";
  origin = "https://${hostname}:8444";
  kavitaOrigin = "https://${hostname}:8443";
  tlsDirectory = "/var/lib/kanidm-tls";
  tailscale = lib.getExe config.services.tailscale.package;
  identity = config.home-manager.users.lucas.programs.git.settings.user;
in
{
  sops.secrets."kanidm/admin-password" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };
  sops.secrets."kanidm/idm-admin-password" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };
  sops.secrets."kavita/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };

  services.kanidm = {
    package = pkgs.kanidm_1_11.withSecretProvisioning;
    client = {
      enable = true;
      settings.uri = origin;
    };
    server = {
      enable = true;
      settings = {
        domain = hostname;
        inherit origin;
        bindaddress = "127.0.0.1:8445";
        tls_key = "${tlsDirectory}/key.pem";
        tls_chain = "${tlsDirectory}/cert.pem";
        online_backup = {
          path = "/var/backup/kanidm";
          schedule = "0 22 * * *";
          versions = 7;
        };
      };
    };
    provision = {
      enable = true;
      instanceUrl = origin;
      acceptInvalidCerts = false;
      adminPasswordFile = config.sops.secrets."kanidm/admin-password".path;
      idmAdminPasswordFile = config.sops.secrets."kanidm/idm-admin-password".path;
      groups = {
        "kavita.users" = { };
        "kavita.admins" = { };
      };
      persons.lucas = {
        displayName = identity.name;
        mailAddresses = [ identity.email ];
        groups = [
          "kavita.users"
          "kavita.admins"
        ];
      };
      systems.oauth2.kavita = {
        displayName = "Kavita";
        originUrl = [
          "${kavitaOrigin}/signin-oidc"
          "${kavitaOrigin}/signout-callback-oidc"
        ];
        originLanding = "${kavitaOrigin}/";
        basicSecretFile = config.sops.secrets."kavita/oidc-secret".path;
        preferShortUsername = true;
        scopeMaps."kavita.users" = [
          "openid"
          "email"
          "profile"
        ];
      };
    };
  };

  systemd.services.kanidm = {
    after = [
      "kanidm-tls.service"
      "tailscale-serve-kanidm.service"
    ];
    # tailscale may not be connected at boot, so start with the certificate already on disk
    # and retry until provisioning reaches the serve endpoint
    wants = [
      "kanidm-tls.service"
      "tailscale-serve-kanidm.service"
    ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  systemd.services.kanidm-tls = {
    description = "Tailscale certificate for Kanidm";
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.diffutils
    ];
    serviceConfig = {
      Type = "oneshot";
      Group = "kanidm";
      StateDirectory = "kanidm-tls";
      StateDirectoryMode = "0750";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 10;
    };
    script = ''
      temporary=$(mktemp -d "$STATE_DIRECTORY/.renew.XXXXXX")
      trap 'rm -rf "$temporary"' EXIT
      ${tailscale} cert --min-validity=720h \
        --cert-file="$temporary/cert.pem" --key-file="$temporary/key.pem" ${hostname}
      if ! cmp -s "$temporary/cert.pem" "$STATE_DIRECTORY/cert.pem" \
        || ! cmp -s "$temporary/key.pem" "$STATE_DIRECTORY/key.pem"; then
        install -o root -g kanidm -m 0640 "$temporary/key.pem" "$STATE_DIRECTORY/key.pem"
        install -o root -g kanidm -m 0640 "$temporary/cert.pem" "$STATE_DIRECTORY/cert.pem"
        if ${pkgs.systemd}/bin/systemctl is-active --quiet kanidm.service; then
          ${pkgs.systemd}/bin/systemctl --no-block try-restart kanidm.service
        fi
      fi
    '';
  };

  systemd.timers.kanidm-tls = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # provisioning uses the public hostname so certificate validation remains enabled
  systemd.services.tailscale-serve-kanidm = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 10;
      ExecStart = "${tailscale} serve --bg --tcp=8444 tcp://127.0.0.1:8445";
      ExecStop = "${tailscale} serve --tcp=8444 off";
    };
  };

  services.restic.backups.b2 = {
    paths = [ cfg.server.settings.online_backup.path ];
  };
}
