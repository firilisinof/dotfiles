{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.qbittorrent;
  profile = "${cfg.profileDir}/qBittorrent";
  categories = pkgs.writeText "qbittorrent-categories.json" (
    builtins.toJSON {
      movies.save_path = "/srv/media/library/movies";
      series.save_path = "/srv/media/library/series";
      archive-movies.save_path = "/srv/media/archive/movies";
      archive-series.save_path = "/srv/media/archive/series";
    }
  );
in
{
  imports = [ ./network.nix ];

  users.groups.media = { };
  users.users.jellyfin.extraGroups = [ "media" ];

  sops.secrets."qbittorrent/admin-password" = { };
  sops.secrets."qbittorrent/password-hash" = { };
  sops.templates."qbittorrent.conf" = {
    owner = cfg.user;
    group = cfg.group;
    mode = "0400";
    content = ''
      [LegalNotice]
      Accepted=true

      [BitTorrent]
      Session\Interface=airvpn
      Session\InterfaceName=airvpn
      Session\DefaultSavePath=/srv/media/downloads/complete
      Session\TempPath=/srv/media/downloads/incomplete
      Session\TempPathEnabled=true
      Session\DisableAutoTMMByDefault=false
      Session\DisableAutoTMMTriggers\CategoryChanged=false
      Session\DisableAutoTMMTriggers\CategorySavePathChanged=false
      Session\LSDEnabled=false

      [Network]
      PortForwardingEnabled=false

      [WebUI]
      Address=10.200.0.2
      Port=8080
      Username=lucas
      Password_PBKDF2="@ByteArray(${config.sops.placeholder."qbittorrent/password-hash"})"
      LocalHostAuth=true
      AuthSubnetWhitelistEnabled=false
      HostHeaderValidation=true
      ServerDomains=torrents.firilisinof.com
      CSRFProtection=true
      ClickjackingProtection=true
      SecureCookie=true
      ReverseProxySupportEnabled=true
      TrustedReverseProxiesList=10.200.0.1
      UseUPnP=false
    '';
  };

  services.qbittorrent = {
    enable = true;
    group = "media";
    profileDir = "/srv/qbittorrent";
    webuiPort = 8080;
    torrentingPort = 10943;
    openFirewall = false;
  };

  systemd.tmpfiles.rules = [
    "d ${cfg.profileDir} 0750 qbittorrent media - -"
    "d /srv/media 2750 qbittorrent media - -"
    "d /srv/media/downloads 2750 qbittorrent media - -"
    "d /srv/media/downloads/complete 2770 qbittorrent media - -"
    "d /srv/media/downloads/incomplete 2770 qbittorrent media - -"
    "d /srv/media/library 2750 qbittorrent media - -"
    "d /srv/media/library/movies 2770 qbittorrent media - -"
    "d /srv/media/library/series 2770 qbittorrent media - -"
    "d /srv/media/archive 2750 qbittorrent media - -"
    "d /srv/media/archive/movies 2770 qbittorrent media - -"
    "d /srv/media/archive/series 2770 qbittorrent media - -"
  ];
  systemd.tmpfiles.settings.qbittorrent = {
    "${profile}/".d.mode = lib.mkForce "0750";
    "${profile}/config/".d.mode = lib.mkForce "0750";
  };

  systemd.services.qbittorrent = {
    requires = [ "torrents-network.service" ];
    after = [
      "torrents-network.service"
      "wireguard-airvpn.target"
    ];
    bindsTo = [ "torrents-network.service" ];
    partOf = [ "torrents-network.service" ];
    preStart = ''
      if [ ! -e ${profile}/config/qBittorrent.conf ]; then
        ${pkgs.coreutils}/bin/install -m 0600 ${
          config.sops.templates."qbittorrent.conf".path
        } ${profile}/config/qBittorrent.conf
      fi
      if [ ! -e ${profile}/config/categories.json ]; then
        ${pkgs.coreutils}/bin/install -m 0600 ${categories} ${profile}/config/categories.json
      fi
    '';
    serviceConfig = {
      NetworkNamespacePath = "/run/netns/torrents";
      BindReadOnlyPaths = [ "/etc/netns/torrents/resolv.conf:/etc/resolv.conf" ];
      ProtectSystem = lib.mkForce "strict";
      ReadWritePaths = [
        cfg.profileDir
        "/srv/media"
      ];
      UMask = "0007";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.services.jellyfin.serviceConfig.ReadOnlyPaths = [
    "/srv/media/library"
    "/srv/media/archive"
  ];

  services.restic.backups.b2.exclude = [
    "/srv/media/downloads"
    "/srv/media/library"
    "${profile}/data/logs"
  ];
  systemd.services.restic-backups-b2 = {
    preStart = lib.mkAfter ''
      rm -f /run/restic-qbittorrent-stopped
      if ${pkgs.systemd}/bin/systemctl is-active --quiet qbittorrent.service; then
        ${pkgs.systemd}/bin/systemctl stop qbittorrent.service
        touch /run/restic-qbittorrent-stopped
      fi
    '';
    postStop = lib.mkAfter ''
      if [ -e /run/restic-qbittorrent-stopped ]; then
        ${pkgs.systemd}/bin/systemctl start qbittorrent.service
        rm -f /run/restic-qbittorrent-stopped
      fi
    '';
  };

  services.caddy.virtualHosts."torrents.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy 10.200.0.2:8080";
  };
}
