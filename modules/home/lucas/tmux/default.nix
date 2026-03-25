{ ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    newSession = true;
    keyMode = "vi";
    extraConfig = ''
      set -g mouse on
      set -g base-index 1
      setw -g pane-base-index 1
    '';
  };
}
