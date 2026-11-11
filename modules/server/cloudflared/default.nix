{ config, lib, ... }:

let
  cfg = config.dotfiles.tunnel;
  # created once with `cloudflared tunnel create pi5`
  id = "1b2307c9-1b21-4d86-99f5-90698ab10c9d";
in
{
  # everything else on the pi5 is served only over tailscale
  options.dotfiles.tunnel = {
    ingress = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str lib.types.attrs);
      default = { };
      description = "Public hostnames served through the Cloudflare tunnel, as cloudflared ingress rules.";
    };
    groups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Groups cloudflared joins to reach origins on unix sockets.";
    };
  };

  config = {
    sops.secrets."cloudflared/tunnel" = { };

    services.cloudflared = {
      enable = true;
      tunnels.${id} = {
        credentialsFile = config.sops.secrets."cloudflared/tunnel".path;
        inherit (cfg) ingress;
        default = "http_status:404";
      };
    };

    systemd.services."cloudflared-tunnel-${id}".serviceConfig.SupplementaryGroups = cfg.groups;
  };
}
