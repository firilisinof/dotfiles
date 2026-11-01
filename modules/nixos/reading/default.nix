{
  config,
  lib,
  pkgs,
  ...
}:

let
  shelfmarkImage = "ghcr.io/calibrain/shelfmark@sha256:51091200afb8afd9f1dba07596e9e81a96d499e42ff96fee676b29a7cac24016";
  kapowarrImage = "docker.io/mrcas/kapowarr@sha256:cd3f004caff59636dde73b06df5b2f8068b485b47ff5fe82f6129562c0f2ac3b";
  suwayomiJar = pkgs.fetchurl {
    url = "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v2.4.2366/Suwayomi-Server-v2.4.2366.jar";
    hash = "sha256-r5/rIK+dfr6eMHaebG68f8erHERziNQuAoCx2l/ge/0=";
  };
  apps = {
    shelfmark = 8084;
    kapowarr = 5656;
    suwayomi = 4567;
  };
  units = [
    "reading-import-manga.timer"
    "reading-import-manga.service"
    "podman-shelfmark.service"
    "podman-kapowarr.service"
    "suwayomi-server.service"
  ];
in
{
  users.groups.reading.gid = 803;
  users.users = {
    shelfmark = {
      isSystemUser = true;
      uid = 803;
      group = "reading";
    };
    kapowarr = {
      isSystemUser = true;
      uid = 804;
      group = "reading";
    };
    suwayomi = {
      isSystemUser = true;
      uid = 805;
      group = "reading";
      home = "/srv/suwayomi";
    };
    kavita.extraGroups = [ "reading" ];
    qbittorrent.extraGroups = [ "reading" ];
  };

  sops.secrets =
    lib.genAttrs
      (map (name: "reading/${name}") [
        "annas-member-key"
        "comicvine-api-key"
        "shelfmark-password"
        "shelfmark-api-key"
        "kapowarr-password"
        "suwayomi-password"
      ])
      (name: {
        restartUnits =
          if name == "reading/suwayomi-password" then
            [ "suwayomi-server.service" ]
          else if
            builtins.elem name [
              "reading/comicvine-api-key"
              "reading/kapowarr-password"
            ]
          then
            [ "reading-setup.service" ]
          else
            [ "podman-shelfmark.service" ];
      });
  sops.templates."shelfmark.env".content = ''
    SHELFMARK_API_KEY=${config.sops.placeholder."reading/shelfmark-api-key"}
  '';

  systemd.tmpfiles.rules = [
    "d /srv/reading 2750 root reading - -"
    "d /srv/reading/books 2770 shelfmark reading - -"
    "d /srv/reading/comics 2770 kapowarr reading - -"
    "d /srv/reading/manga 2770 suwayomi reading - -"
    "d /srv/shelfmark 0700 shelfmark reading - -"
    "d /srv/kapowarr 0700 kapowarr reading - -"
    "d /srv/kapowarr/db 0700 kapowarr reading - -"
    "d /srv/kapowarr/logs 0700 kapowarr reading - -"
    "d /srv/suwayomi 0700 suwayomi reading - -"
    "d /srv/media/downloads/shelfmark 2770 qbittorrent reading - -"
    "d /srv/media/downloads/shelfmark-tmp 2770 shelfmark reading - -"
    "d /srv/media/downloads/kapowarr 2770 kapowarr reading - -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      shelfmark = {
        image = shelfmarkImage;
        autoRemoveOnStop = false;
        environment = {
          PUID = "803";
          PGID = "803";
          FLASK_HOST = "127.0.0.1";
          FLASK_PORT = "8084";
          CONFIG_DIR = "/config";
          INGEST_DIR = "/srv/reading/books";
          TMP_DIR = "/downloads-tmp";
          TZ = "Europe/Paris";
          SESSION_COOKIE_SECURE = "true";
        };
        environmentFiles = [ config.sops.templates."shelfmark.env".path ];
        volumes = [
          "/srv/shelfmark:/config"
          "/srv/reading/books:/srv/reading/books"
          "/srv/media/downloads/shelfmark:/srv/media/downloads/shelfmark"
          "/srv/media/downloads/shelfmark-tmp:/downloads-tmp"
        ];
        extraOptions = [
          "--network=host"
          "--umask=0007"
          "--shm-size=512m"
          "--dns=1.1.1.1"
        ];
      };
      kapowarr = {
        image = kapowarrImage;
        autoRemoveOnStop = false;
        environment = {
          PUID = "804";
          PGID = "803";
          TZ = "Europe/Paris";
        };
        ports = [ "127.0.0.1:5656:5656" ];
        volumes = [
          "/srv/kapowarr/db:/app/db"
          "/srv/kapowarr/logs:/app/logs"
          "/srv/media/downloads/kapowarr:/app/temp_downloads"
          "/srv/reading/comics:/comics"
        ];
        extraOptions = [
          "--umask=0007"
          "--dns=1.1.1.1"
        ];
      };
    };
  };

  systemd.services = {
    kavita.serviceConfig.SupplementaryGroups = [ "reading" ];
    reading-import-manga = {
      description = "Import completed manga archives into Kavita";
      after = [ "suwayomi-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "suwayomi";
        Group = "reading";
        UMask = "0007";
        ExecStart = "${pkgs.python3}/bin/python3 ${./import-manga.py} /srv/suwayomi/downloads/mangas /srv/reading/manga";
        NoNewPrivileges = true;
        ProtectSystem = true;
        ProtectHome = true;
      };
    };
    podman-shelfmark = {
      after = [ "prowlarr.service" ];
      preStart = "${pkgs.python3}/bin/python3 ${./prepare.py} shelfmark";
    };
    suwayomi-server = {
      description = "Suwayomi manga acquisition server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStartPre = [ "+${pkgs.python3}/bin/python3 ${./prepare.py} suwayomi" ];
        User = "suwayomi";
        Group = "reading";
        UMask = "0007";
        ExecStart = "${pkgs.jdk21_headless}/bin/java -Xmx768m -Dsuwayomi.tachidesk.config.server.rootDir=/srv/suwayomi -jar ${suwayomiJar}";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/srv/suwayomi"
        ];
        InaccessiblePaths = [ "-/run/nscd" ];
        BindReadOnlyPaths = config.systemd.services.prowlarr.serviceConfig.BindReadOnlyPaths;
      };
    };
    reading-setup = {
      description = "Configure reading acquisition services";
      wantedBy = [ "multi-user.target" ];
      wants = units;
      after = units;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${./setup.py}";
        UMask = "0077";
        TimeoutStartSec = "5min";
      };
    };
    restic-backups-b2 = {
      preStart = lib.mkBefore ''
        install -d -m 0700 /run/reading-backup
        for unit in ${lib.escapeShellArgs units}; do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet "$unit"; then
            touch "/run/reading-backup/$unit"
            ${pkgs.systemd}/bin/systemctl stop "$unit"
          fi
        done
      '';
      postStop = lib.mkAfter ''
        for unit in ${lib.escapeShellArgs units}; do
          if test -e "/run/reading-backup/$unit"; then
            ${pkgs.systemd}/bin/systemctl start "$unit"
            rm -f "/run/reading-backup/$unit"
          fi
        done
      '';
    };
  };

  systemd.timers.reading-import-manga = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitInactiveSec = "2min";
    };
  };

  services.restic.backups.b2.exclude = [
    "/srv/shelfmark/logs"
    "/srv/shelfmark/covers"
    "/srv/kapowarr/logs"
    "/srv/suwayomi/logs"
    "/srv/suwayomi/cache"
    "/srv/suwayomi/downloads"
  ];

  services.caddy.virtualHosts = lib.mapAttrs' (
    name: port:
    lib.nameValuePair "${name}.firilisinof.com" {
      useACMEHost = "firilisinof.com";
      logFormat = null;
      extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
    }
  ) apps;
}
