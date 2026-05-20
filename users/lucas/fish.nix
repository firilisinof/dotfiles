{ ... }:
{
  programs = {
    fish.enable = true;

    starship = {
      enable = true;
      enableFishIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
    };
  };
}
