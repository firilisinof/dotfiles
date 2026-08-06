{
  pkgs,
  inputs,
  user,
  host,
  ...
}:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager
  ];

  environment = {
    etc."sudoers.d/10-passwordless".text = ''
      ${user.name} ALL=(ALL:ALL) NOPASSWD:SETENV: ALL
    '';
    variables = {
      SSH_AUTH_SOCK = "${user.home}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
    };
    profiles = [
      "$HOME/.nix-profile"
    ];
    shells = [ pkgs.fish ];
  };

  fonts.packages = [
    pkgs.roboto
    pkgs.nerd-fonts.roboto-mono
    pkgs.gyre-fonts
    pkgs.liberation_ttf
    pkgs.atkinson-hyperlegible-next
    pkgs.atkinson-hyperlegible-mono
    pkgs.fira-math
  ];

  networking = {
    hostName = host.name;
    computerName = host.name;
    localHostName = host.name;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [
        "root"
        user.name
      ];
    };
    gc.automatic = true;
  };

  nixpkgs = {
    hostPlatform = host.system;
    config.allowUnfree = true;
  };

  programs = {
    fish.enable = true;
    man.enable = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  users.users.${user.name} = {
    home = user.home;
    shell = pkgs.fish;
  };

  system = {
    primaryUser = user.name;
    startup.chime = false;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;

    activationScripts.postActivation.text = ''
      echo "Setting ${user.name}'s login shell to fish..."
      dscl . -create /Users/${user.name} UserShell ${pkgs.fish}/bin/fish
    '';

    defaults = {
      dock = {
        mru-spaces = false;
        autohide = true;
        orientation = "bottom";
        tilesize = 64;
        show-recents = false;
        minimize-to-application = false;
        expose-animation-duration = 0.15;
        showhidden = true;
        persistent-apps = [ ];
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
      };
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = false;
        FXPreferredViewStyle = "Nlsv";
      };
      spaces = {
        spans-displays = false;
      };
      WindowManager = {
        GloballyEnabled = false;
        StandardHideDesktopIcons = true;
        HideDesktop = true;
        EnableStandardClickToShowDesktop = false;
      };
      NSGlobalDomain = {
        AppleInterfaceStyle = null;
        ApplePressAndHoldEnabled = false;
        AppleSpacesSwitchOnActivate = true;
        AppleShowAllExtensions = true;
        AppleWindowTabbingMode = "manual";
        InitialKeyRepeat = 20;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = true;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = true;
        NSAutomaticInlinePredictionEnabled = true;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSWindowShouldDragOnGesture = true;
        PMPrintingExpandedStateForPrint = true;
      };
      trackpad = {
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = false;
        Clicking = true;
      };
    };
  };

  nix-homebrew = {
    enable = true;
    user = user.name;
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [
      {
        name = "d12frosted/emacs-plus";
        trusted = true;
      }
    ];

    brews = [
      "blueutil"
    ];

    casks = [
      "ghostty"
      "visual-studio-code"

      "obsidian"
      "google-chrome"
      "firefox"

      "google-drive"

      "mullvad-vpn"

      "anki"
      "calibre"
      "zotero"

      "discord"
      "betterdisplay"
      "balenaetcher"
      "transmission"

      "emacs-plus-app"
      "wacom-tablet"
      "osu"
    ];

    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs user; };

    users.${user.name} = import ./home.nix;
  };
}
