{ homebrew-cask, homebrew-core, aerospace, janky-borders, swipeaerospace, ... }:

{
  nix-homebrew = {
    enable = true;
    user = "lucas";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "nikitabobko/homebrew-tap" = aerospace;
      "FelixKratz/homebrew-formulae" = janky-borders;
      "mediosz/homebrew-tap" = swipeaerospace;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    brews = [
      "FelixKratz/formulae/borders"
    ];
    casks = [
      "bitwarden"
      "nikitabobko/tap/aerospace"
      "mediosz/tap/swipeaerospace"
      "ghostty"
      "google-chrome"
    ];
    masApps = {};
  };
}
