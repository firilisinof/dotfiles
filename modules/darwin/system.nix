{ config, lib, ... }:

let
  user = config.system.primaryUser;
in
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "antigravity-cli"
      "claude-code"
      "firefox-bin-unwrapped"
      "google-chrome"
      "obsidian"
    ];
  programs.zsh.enable = true;

  system.defaults = {
    finder = {
      AppleShowAllFiles = false;
      ShowStatusBar = true;
      ShowPathbar = true;
      FXRemoveOldTrashItems = true;
      FXPreferredViewStyle = "Nlsv";
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = false;
      NewWindowTarget = "Other";
      NewWindowTargetPath = "file://${config.users.users.${user}.home}/Downloads/";
    };
    dock = {
      autohide = true;
      expose-group-apps = true;
      launchanim = false;
      mineffect = "genie";
      minimize-to-application = true;
      mru-spaces = false;
      orientation = "bottom";
      showAppExposeGestureEnabled = true;
      showDesktopGestureEnabled = true;
      showMissionControlGestureEnabled = true;
      showLaunchpadGestureEnabled = true;
      show-process-indicators = true;
      show-recents = false;
      tilesize = 48;
      magnification = true;
      largesize = 59;
      wvous-tl-corner = 2;
      wvous-tr-corner = 12;
      wvous-br-corner = 1;
    };
    CustomUserPreferences."com.apple.dock" = {
      enterMissionControlByTopWindowDrag = true;
      wvous-tl-modifier = 1048576;
      wvous-tr-modifier = 1048576;
      wvous-br-modifier = 0;
    };
    CustomUserPreferences.NSGlobalDomain = {
      NSCloseAlwaysConfirmsChanges = false;
      NSQuitAlwaysKeepsWindows = false;
    };
    NSGlobalDomain = {
      AppleEnableSwipeNavigateWithScrolls = true;
      AppleIconAppearanceTheme = "ClearAutomatic";
      AppleKeyboardUIMode = 0;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Automatic";
      AppleSpacesSwitchOnActivate = true;
      AppleWindowTabbingMode = "always";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSTableViewDefaultSizeMode = 2;
      "com.apple.keyboard.fnState" = true;
      "com.apple.sound.beep.volume" = 1.0;
      "com.apple.sound.beep.feedback" = 1;
      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.5;
      "com.apple.swipescrolldirection" = true;
      _HIHideMenuBar = false;
      AppleReduceDesktopTinting = false;
    };
    trackpad = {
      Clicking = true;
      Dragging = false;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
      TrackpadThreeFingerTapGesture = 0;
      ActuateDetents = true;
      DragLock = false;
      ForceSuppressed = false;
      TrackpadCornerSecondaryClick = 0;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerPinchGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadMomentumScroll = true;
      TrackpadPinch = true;
      TrackpadRotate = true;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
      TrackpadTwoFingerDoubleTapGesture = true;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };
    WindowManager = {
      GloballyEnabled = false;
      EnableStandardClickToShowDesktop = false;
      AutoHide = true;
      AppWindowGroupingBehavior = false;
      StandardHideDesktopIcons = true;
      HideDesktop = true;
      EnableTilingByEdgeDrag = true;
      EnableTopTilingByEdgeDrag = true;
      EnableTilingOptionAccelerator = true;
      EnableTiledWindowMargins = true;
      StandardHideWidgets = true;
      StageManagerHideWidgets = true;
    };
    menuExtraClock = {
      ShowDate = 0;
      ShowDayOfWeek = true;
      ShowAMPM = true;
    };
    screencapture = {
      type = "jpg";
      target = "clipboard";
    };
    loginwindow = {
      GuestEnabled = false;
      HideUserAvatarAndName = false;
    };
    hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };
    spaces.spans-displays = false;
    universalaccess.reduceMotion = false;
  };

  system.startup.chime = false;

  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u ${user})" sudo -u ${user} -- defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
    launchctl asuser "$(id -u ${user})" sudo -u ${user} -- defaults -currentHost write com.apple.controlcenter NowPlaying -int 18
  '';
}
