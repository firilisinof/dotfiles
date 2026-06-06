{ ... }:
{
  home.sessionVariables = {
    EDITOR = "code --wait --skip-welcome --skip-release-notes --disable-telemetry --skip-add-to-recently-opened";
  };

  programs = {
    fish.enable = true;

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
    };
  };
}
