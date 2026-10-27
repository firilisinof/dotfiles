{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.nerd-fonts.meslo-lg ];
  programs.ghostty = {
    enable = true;
    # ghostty-bin is the macOS build, other platforms keep the module default
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin pkgs.ghostty-bin;
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
