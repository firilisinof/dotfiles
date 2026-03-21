{ homebrew-cask, homebrew-core, homebrew-aerospace, ... }:

{
  nix-homebrew = {
    enable = true;
    user = "lucas";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "nikitabobko/homebrew-tap" = homebrew-aerospace;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    brews = [];
    casks = [
      "bitwarden"
      "nikitabobko/tap/aerospace"
      "ghostty"
    ];
    masApps = {};
  };
}
