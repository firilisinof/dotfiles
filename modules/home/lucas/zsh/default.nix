{ pkgs, lib, config, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    
    dotDir = "${config.xdg.configHome}/zsh";

    shellAliases = lib.mkMerge [
      (lib.mkIf config.programs.bat.enable { cat = "bat --plain"; })
      (lib.mkIf config.programs.lsd.enable {
        tree = "lsd --tree";
      })
      {
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
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
      WORDCHARS=''${WORDCHARS//\/}
      bindkey '^W' backward-kill-word
      bindkey '^[f' forward-word
      bindkey '^[[1;3C' forward-word
      bindkey '^[[1;5C' forward-word

      rfv() {
        command rg --color=always --line-number --no-heading --smart-case "''${*:-}" |
          fzf --ansi \
              --color "hl:-1:underline,hl+:-1:underline:reverse" \
              --delimiter : \
              --preview 'bat --color=always {1} --highlight-line {2}' \
              --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
              --bind 'enter:become(${pkgs.neovim}/bin/nvim {1} +{2})'
      }
    '';
  };
}
