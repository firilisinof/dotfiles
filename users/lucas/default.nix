{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./fish.nix
  ];

  home = {
    username = "lucas";
    homeDirectory = "/Users/lucas";

    packages = with pkgs; [
      curl
      wget
      git
      ripgrep
      nixfmt
    ];

    shell = {
      enableFishIntegration = true;
    };

    file = {
      ".config/ghostty/config".source = ./files/ghostty/config;
      ".claude/CLAUDE.md".source = ./files/claude/CLAUDE.md;
    };

    stateVersion = "26.05";
  };

  programs = {
    home-manager.enable = true;
    man.generateCaches = false;
  };
}
