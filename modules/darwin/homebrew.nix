{ homebrew-cask, homebrew-core, homebrew-aerospace, homebrew-janky-borders, ... }:

{
  nix-homebrew = {
    enable = true;
    user = "lucas";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "nikitabobko/homebrew-tap" = homebrew-aerospace;
      "FelixKratz/homebrew-formulae" = homebrew-janky-borders;
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
      "ghostty"
    ];
    masApps = {};
  };
}
