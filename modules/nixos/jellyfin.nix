{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.jellyfin;
  database = "${cfg.dataDir}/data/jellyfin.db";
  networkConfig = pkgs.writeText "jellyfin-network.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <NetworkConfiguration>
      <RequireHttps>false</RequireHttps>
      <BaseUrl />
      <PublicHttpsPort>8920</PublicHttpsPort>
      <InternalHttpPort>8096</InternalHttpPort>
      <InternalHttpsPort>8920</InternalHttpsPort>
      <PublicHttpPort>8096</PublicHttpPort>
      <EnableHttps>false</EnableHttps>
      <AutoDiscovery>false</AutoDiscovery>
      <EnableUPnP>false</EnableUPnP>
      <EnableIPv4>true</EnableIPv4>
      <EnableIPv6>false</EnableIPv6>
      <EnableRemoteAccess>true</EnableRemoteAccess>
      <LocalNetworkAddresses>
        <string>127.0.0.1</string>
      </LocalNetworkAddresses>
      <KnownProxies>
        <string>127.0.0.1</string>
      </KnownProxies>
      <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
    </NetworkConfiguration>
  '';
in
{
  sops.secrets."jellyfin/admin-password" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.jellyfin = {
    enable = true;
    dataDir = "/srv/jellyfin";
    cacheDir = "/var/cache/jellyfin";
    openFirewall = false;
    hardwareAcceleration.enable = false;
  };

  users.users.jellyfin.extraGroups = [ "youtube" ];

  systemd.services.jellyfin = {
    preStart = ''
      networkConfigPath=${lib.escapeShellArg "${cfg.configDir}/network.xml"}
      if [ ! -e "$networkConfigPath" ]; then
        ${lib.getExe' pkgs.coreutils "install"} -m 0600 ${networkConfig} "$networkConfigPath"
      fi
    '';
    serviceConfig = {
      ReadOnlyPaths = [ "/srv/youtube" ];
    };
  };

  services.restic.backups.b2 = {
    exclude = [
      "${cfg.dataDir}/data/jellyfin.db*"
      cfg.logDir
    ];
    sqlite.jellyfin = {
      path = database;
      user = cfg.user;
    };
  };

  services.caddy.virtualHosts."watch.firilisinof.com" = {
    useACMEHost = "firilisinof.com";
    logFormat = null;
    extraConfig = "reverse_proxy 127.0.0.1:8096";
  };
}
