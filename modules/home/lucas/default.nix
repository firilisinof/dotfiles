{ pkgs, ... }:

{
  imports = [
    ./git
    ./gh
    ./zsh
    ./ssh
  ];
  xdg.enable = true;
  programs.helix = {
    enable = true;
    defaultEditor = true;
  };
}
