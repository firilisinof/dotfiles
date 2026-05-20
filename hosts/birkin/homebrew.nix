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
      # Terminal & editors
      "ghostty"
      "visual-studio-code"

      # Notes & knowledge
      "obsidian"

      # AI assistants
      "claude"
      "codex-app"

      # Cloud storage
      "google-drive"
    ];
  };
}
