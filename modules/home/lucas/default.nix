{ ... }:

{
  imports = [
    ./packages.nix
    ./aerospace
    ./bat
    ./direnv
    ./environment.nix
    ./fzf
    ./ghostty
    ./git
    ./lsd
    ./man
    ./neovim
    ./tmux
    ./wallpaper
    ./zellij
    ./zsh
    ./vscode
  ];

  home.username = "lucas";
  home.homeDirectory = "/Users/lucas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
