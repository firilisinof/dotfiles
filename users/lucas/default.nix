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

    file =
      let soundLikeMe = ./files/claude/skills/sound-like-me/SKILL.md;
      in {
        ".config/ghostty/config".source = ./files/ghostty/config;
        ".claude/CLAUDE.md".source = ./files/claude/CLAUDE.md;
        ".claude/skills/sound-like-me/SKILL.md".source = soundLikeMe;
        ".agents/skills/sound-like-me/SKILL.md".source = soundLikeMe;
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
