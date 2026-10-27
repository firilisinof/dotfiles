{ lib, ... }:

{
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
}
