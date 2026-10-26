{ ... }:

{
  programs.ghostty = {
    enable = true;
    # Homebrew installs the macOS application
    package = null;
    settings = {
      font-family = "MesloLGS Nerd Font";
      font-size = 16;
      theme = "Apple System Colors Light";
    };
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
  };
  xdg.configFile."ghostty/config".force = true;
}
