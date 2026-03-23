{ pkgs, lib, ... }:

{
  programs.zellij = {
    enable = true;
    package = pkgs.zellij;
    enableZshIntegration = false;

    extraConfig = ''
      themes {
        github-light {
          fg 87 96 106
          bg 246 248 250
          red 207 34 46
          green 26 127 55
          yellow 154 103 0
          blue 9 105 218
          magenta 130 80 223
          orange 188 76 0
          cyan 27 124 131
          black 246 248 250
          white 31 35 40
        }
      }

      default_shell "${lib.getExe pkgs.zsh}"
      theme "github-light"
      copy_command "pbcopy"
      copy_clipboard "system"
      show_startup_tips false
    '';
  };
}
