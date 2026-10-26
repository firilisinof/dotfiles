{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./gh.nix
    ./zsh.nix
  ];
  xdg.enable = true;
  home.packages = [ pkgs.eza ];
}
