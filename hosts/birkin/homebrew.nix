{ inputs, user, ... }:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

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

    brews = [
      "blueutil"
    ];

    casks = [
      "ghostty"
      "visual-studio-code"

      "obsidian"

      "claude"
      "claude-code"
      "codex-app"

      "google-chrome"
      "firefox"

      "google-drive"

      "mullvad-vpn"
      
      "anki"
      "calibre"
      "zotero"

      "discord"
      "betterdisplay"
    ];
  };
}
