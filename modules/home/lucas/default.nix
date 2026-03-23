{ ... }:

{
  imports = [
    ./packages.nix
    ./aerospace
    ./bat
    ./environment.nix
    ./fzf
    ./ghostty
    ./git
    ./lsd
    ./man
    ./neovim
    ./zellij
    ./zsh
    ./vscode
  ];

  home.username = "lucas";
  home.homeDirectory = "/Users/lucas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
