{ lib, ... }:

{
  imports = [ ./homebrew.nix ];
  # determinate owns the Nix daemon and its configuration
  nix.enable = false;
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "antigravity-cli"
      "claude-code"
      "firefox-bin-unwrapped"
      "google-chrome"
      "obsidian"
    ];
  programs.zsh.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
