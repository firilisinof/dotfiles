{ pkgs, lib, config, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
    ];
  };

  programs.zsh = {
    enable = true;
    
    dotDir = "${config.xdg.configHome}/zsh";

    shellAliases = lib.mkMerge [
      (lib.mkIf config.programs.bat.enable { cat = "bat --plain"; })
      (lib.mkIf config.programs.lsd.enable {
        tree = "lsd --tree";
      })
      rec {
        nano = "nvim";
        vi = "nvim";
        vim = "nvim";
        vimdiff = "nvim -d";
      }
    ];

    envExtra = ''
      export SHELL=$(which zsh)
    '';

    initContent = ''
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
      bindkey '^W' backward-kill-word
    '';
  };
}
