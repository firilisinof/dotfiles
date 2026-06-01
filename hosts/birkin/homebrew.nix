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

    casks = [
      "ghostty"
      "visual-studio-code"

      "obsidian"

      "claude"
      "claude-code"
      "codex-app"

      "google-chrome"
      "google-drive"

      "mullvad-vpn"
      "anki"
      "calibre"

      "betterdisplay"
    ];
  };
}
