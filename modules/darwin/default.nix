{ lib, ... }:

{
  imports = [ ./homebrew.nix ];
  # determinate owns the Nix daemon and its configuration
  nix.enable = false;
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "antigravity-cli"
      "antigravity-bin"
      "beeper-bin"
      "chatgpt-bin"
      "claude-bin"
      "claude-code"
      "discord-bin"
      "firefox-bin-unwrapped"
      "google-chrome"
      "google-gemini-bin"
      "obsidian"
      "notion-bin"
      "visual-studio-code-bin"
    ];
  programs.zsh.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
