{
  config,
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
      poppler-utils
      nodejs
      python313
      restic
      rclone
      uv
    ];

    shell = {
      enableFishIntegration = true;
    };

    sessionPath = [
      "${user.home}/.local/bin"
    ];

    sessionVariables = {
      EDITOR = "code --wait --skip-welcome --skip-release-notes --disable-telemetry --skip-add-to-recently-opened";
      DIRENV_WARN_TIMEOUT = 0;
    };

    stateVersion = "26.05";
  };

  home.file.".local/bin/run-backup" = {
    source = ./bin/run-backup.py;
    executable = true;
  };

  launchd.agents.run-backup = {
    enable = true;
    config = {
      ProgramArguments = [ "${user.home}/.local/bin/run-backup" ];
      StartCalendarInterval = [
        {
          Hour = 12;
          Minute = 0;
        }
      ];
      EnvironmentVariables = {
        PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${user.home}/Library/Logs/run-backup.log";
      StandardErrorPath = "${user.home}/Library/Logs/run-backup.log";
    };
  };

  launchd.agents.emacs = {
    enable = true;
    config = {
      ProgramArguments = [
        "/Applications/Emacs.app/Contents/MacOS/Emacs"
        "--fg-daemon"
      ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ProcessType = "Interactive";
      WorkingDirectory = user.home;
      EnvironmentVariables = {
        PATH = lib.concatStringsSep ":" [
          "${user.home}/.local/bin"
          "${config.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
          "/opt/homebrew/bin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
      };
      StandardOutPath = "${user.home}/Library/Logs/emacs.log";
      StandardErrorPath = "${user.home}/Library/Logs/emacs.log";
    };
  };

  xdg.configFile."ghostty/config".source = ./config/ghostty/config;

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

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          IdentityAgent = "${user.home}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
        };
        "SuperMaquina" = {
          HostName = "143.107.45.126";
          Port = 2031;
          User = "lsrosa";
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
