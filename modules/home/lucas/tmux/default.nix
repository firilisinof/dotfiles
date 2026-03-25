{ ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    newSession = true;
    keyMode = "vi";
    extraConfig = ''
      # Prefix: easier to reach than the default C-b.
      unbind C-b
      set -g prefix C-a
      bind-key C-a send-prefix

      # Split panes with mnemonic keys, then remove the defaults.
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      # Reload config without recreating the session.
      bind r source-file ~/.tmux.conf

      # Move between panes with Vim-style keys after prefix.
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set -g mouse on
      set -g base-index 1
      setw -g pane-base-index 1
      set-option -g allow-rename off

      # Lightweight status/pane styling from the guide's recommendations.
      set -g status-justify left
      set -g status-style 'fg=red'
      set -g status-right '%Y-%m-%d %H:%M '
      set -g status-right-length 50
      setw -g clock-mode-colour yellow
    '';
  };
}
