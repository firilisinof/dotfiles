{ ... }:

{
  system.startup.chime = false;

  system.defaults = {
    dock = {
      mru-spaces = false;
      autohide = true;
      orientation = "bottom";
      tilesize = 64;
      show-recents = false;
      minimize-to-application = false;
      expose-animation-duration = 0.15;
      showhidden = true;
      persistent-apps = [];
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
}
