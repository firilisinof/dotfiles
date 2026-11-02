{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.jellyfin;
  database = "${cfg.dataDir}/data/jellyfin.db";
  enhancedVersion = "12.14.0.0";
  enhancedArchive = pkgs.fetchurl {
    url = "https://github.com/n00bcodr/Jellyfin-Enhanced/releases/download/${enhancedVersion}/Jellyfin.Plugin.JellyfinEnhanced_12.0.0.zip";
    hash = "sha256-y+2w+YoYJ/udlDNyqphiYLsiROlWcsFuWyelJPoyHUM=";
  };
  enhancedManifest = pkgs.writeText "jellyfin-enhanced-meta.json" (
    builtins.toJSON {
      name = "Jellyfin Enhanced";
      guid = "f69e946a-4b3c-4e9a-8f0a-8d7c1b2c4d9b";
      owner = "n00bcodr";
      category = "General";
      version = enhancedVersion;
      targetAbi = "12.0.0.0";
      status = "Active";
      autoUpdate = false;
      assemblies = [ "Jellyfin.Plugin.JellyfinEnhanced.dll" ];
    }
  );
  enhancedPlugin = pkgs.runCommand "jellyfin-enhanced-${enhancedVersion}" { } ''
    ${lib.getExe pkgs.unzip} ${enhancedArchive} -d "$out"
    cp ${enhancedManifest} "$out/meta.json"
  '';
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
  assertions = [
    {
      assertion = lib.versions.major cfg.package.version == "12";
      message = "The pinned Jellyfin Enhanced artifact requires Jellyfin 12.x.";
    }
  ];

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
      pluginPath=${lib.escapeShellArg "${cfg.dataDir}/plugins/JellyfinEnhanced"}
      ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 "$pluginPath"
      ${lib.getExe' pkgs.coreutils "install"} -m 0600 ${enhancedPlugin}/* "$pluginPath/"
      ${lib.getExe pkgs.python3} ${./setup.py} \
        ${lib.escapeShellArg "${cfg.dataDir}/plugins/configurations/Jellyfin.Plugin.JellyfinEnhanced.xml"}
    '';
    serviceConfig = {
      LoadCredential = [ "seerr-api-key:${config.sops.secrets."seerr/api-key".path}" ];
      ReadOnlyPaths = [ "/srv/youtube" ];
    };
  };

  systemd.services.jellyfin-episode-images = {
    description = "Fetch thumbnails for missing Jellyfin episodes";
    wants = [ "jellyfin.service" ];
    after = [ "jellyfin.service" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      ExecStart = "${lib.getExe pkgs.python3} ${./episode_images.py}";
      LoadCredential = [ "admin-password:${config.sops.secrets."jellyfin/admin-password".path}" ];
      TimeoutStartSec = "30min";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictAddressFamilies = [ "AF_INET" ];
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
    };
  };

  systemd.timers.jellyfin-episode-images = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
  };

  services.restic.backups.b2 = {
    exclude = [
      "${cfg.dataDir}/data/jellyfin.db*"
      cfg.logDir
    ];
    sqlite.jellyfin = {
      path = database;
      inherit (cfg) user;
    };
  };

  services.caddy.virtualHosts."watch.firilisinof.com".extraConfig = "reverse_proxy 127.0.0.1:8096";
}
