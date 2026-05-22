{ pkgs, user, ... }:
{
  imports = [
    ./git.nix
    ./fish.nix
  ];

  home = {
    username = user.name;
    homeDirectory = user.home;

    packages = with pkgs; [
      curl
      wget
      git
      ripgrep
      nixfmt
      helix
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
    helix = {
      enable = true;

      settings = {
        theme = "github_light";
      };

      languages = {
        language = [
          {
            name = "nix";
            formatter.command = "nixfmt";
            auto-format = true;
          }
        ];
      };
    };
  };
}
