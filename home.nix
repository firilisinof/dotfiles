{
  lib,
  pkgs,
  user,
  ...
}:
{
  home = {
    username = user.name;
    homeDirectory = user.home;

    packages = with pkgs; [
      curl
      wget
      git
      git-lfs
      ripgrep
      nixfmt
      typst
      typstyle
    ];

    shell = {
      enableFishIntegration = true;
    };

    sessionVariables = {
      EDITOR = "code --wait --skip-welcome --skip-release-notes --disable-telemetry --skip-add-to-recently-opened";
    };

    file.".config/ghostty/config".source = ./files/ghostty/config;

    stateVersion = "26.05";
  };

  programs = {
    home-manager.enable = true;
    man.generateCaches = false;

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        alias = {
          st = "status --short --branch";
          last = "log -1 --stat";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        rebase.autoStash = true;
        user = {
          name = user.fullName;
          email = user.email;
        };
      };
    };

    fish.enable = true;

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
    };
  };
}
