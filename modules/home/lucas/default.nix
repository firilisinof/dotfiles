{ pkgs, ... }:

{
  imports = [
    ./git
    ./gh
    ./zsh
    ./ssh
  ];
  xdg.enable = true;
  home.packages = [ pkgs.eza ];
}
