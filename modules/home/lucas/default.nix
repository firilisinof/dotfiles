{ ... }:

{
  imports = [
    ./packages.nix
    ./aerospace
    ./environment.nix
    ./ghostty
    ./git
    ./neovim
    ./zsh
  ];

  home.username = "lucas";
  home.homeDirectory = "/Users/lucas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
