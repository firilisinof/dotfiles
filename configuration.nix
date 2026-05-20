{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  environment = {
    etc."sudoers.d/10-passwordless".text = ''
      lucas ALL=(ALL:ALL) NOPASSWD:SETENV: ALL
    '';
    variables = {
      SSH_AUTH_SOCK = "/Users/lucas/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
    };
    profiles = [
      "$HOME/.nix-profile"
    ];
    shells = [ pkgs.fish ];
  };

  fonts.packages = [
    pkgs.roboto
    pkgs.nerd-fonts.roboto-mono
  ];

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      substituters = [
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  programs = {
    fish.enable = true;
    man.enable = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = "lucas";
    startup.chime = false;
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
        StandardHideDesktopIcons = false;
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
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
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
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;
  };

  users.users.lucas = {
    home = "/Users/lucas";
    shell = pkgs.fish;
  };
}
