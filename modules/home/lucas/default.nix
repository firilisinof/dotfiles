{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./gh.nix
    ./zsh.nix
    ./ssh.nix
  ];
  xdg.enable = true;
  home.packages = [ pkgs.eza ];
}
