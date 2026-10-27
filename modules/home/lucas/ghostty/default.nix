{ pkgs, ... }:

{
  home.packages = [ pkgs.nerd-fonts.meslo-lg ];
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      font-family = "MesloLGS Nerd Font";
      font-size = 16;
      theme = "Apple System Colors Light";
    };
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
  };
}
