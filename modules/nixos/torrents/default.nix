{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.qbittorrent;
  profile = "${cfg.profileDir}/qBittorrent";

in
{
  imports = [ ./network.nix ];

  users.groups.media = { };

  sops.secrets."qbittorrent/admin-password" = { };
  sops.secrets."qbittorrent/password-hash" = { };
  sops.templates."qbittorrent.conf" = {
    owner = cfg.user;
    inherit (cfg) group;
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
    '';
    serviceConfig = {
      NetworkNamespacePath = "/run/netns/torrents";
      # prevent the host resolver daemon from bypassing AirVPN DNS
      InaccessiblePaths = [ "-/run/nscd" ];
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

  services.restic.backups.b2 = {
    stopUnits = [ "qbittorrent.service" ];
    exclude = [
      "/srv/media/downloads"
      "${profile}/data/logs"
    ];
  };

  services.caddy.virtualHosts."torrents.firilisinof.com".extraConfig =
    "reverse_proxy 10.200.0.2:8080";
}
