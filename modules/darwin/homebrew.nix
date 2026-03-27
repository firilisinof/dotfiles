{ lib, homebrew-cask, homebrew-core, aerospace, janky-borders, swipeaerospace, ... }:

let
  aerospaceEnabled = false;
in
{
  nix-homebrew = {
    enable = true;
    user = "lucas";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    } // lib.optionalAttrs aerospaceEnabled {
      "nikitabobko/homebrew-tap" = aerospace;
      "FelixKratz/homebrew-formulae" = janky-borders;
      "mediosz/homebrew-tap" = swipeaerospace;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    global.autoUpdate = true;

    brews = lib.optionals aerospaceEnabled [
      "FelixKratz/formulae/borders"
    ];

    casks = [
      "bitwarden"
      "ghostty"
      "google-chrome"
      "google-drive"
      "zotero"
      "discord"
      "visual-studio-code"
      "codex-app"
      "claude"
    ] ++ lib.optionals aerospaceEnabled [
      "nikitabobko/tap/aerospace"
      "mediosz/tap/swipeaerospace"
    ];

    masApps = {
      "amphetamine" = 937984704;
    };
  };
}
