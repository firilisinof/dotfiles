{ options, ... }:

let
  settings = {
    substituters = [
      "https://cache.nixos.org?priority=10"
      "https://cache.ysun.co?priority=20"
      # vendor kernel for the pi5
      "https://nixos-raspberrypi.cachix.org?priority=30"
    ];

    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "cache.ysun.co-1:WxPYwT5g3kt9XhUhHPpNLZKI9HIOsVVAuqSHpok8Qt4="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
in
{
  # determinate owns nix.conf on darwin and includes nix.custom.conf
  config =
    if options ? determinateNix then
      { determinateNix.customSettings = settings; }
    else
      { nix.settings = settings; };
}
