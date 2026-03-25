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
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Reload config without recreating the session.
      bind r source-file ~/.tmux.conf

      # Open new windows in current pane directory.
      bind c new-window -c "#{pane_current_path}"

      # Move between panes with Vim-style keys after prefix.
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set -g mouse on
      set -g base-index 1
      setw -g pane-base-index 1
      set-option -g allow-rename off

      # Theme-compatible styling: keep tmux on terminal defaults.
      set -g status-justify left
      set -g status-style 'fg=default,bg=default'
      set -g pane-border-style 'fg=default'
      set -g pane-active-border-style 'fg=default'
      setw -g window-status-style 'fg=default,bg=default'
      setw -g window-status-current-style 'fg=default,bg=default,bold'
      set -g message-style 'fg=default,bg=default'
      set -g status-right '%Y-%m-%d %H:%M '
      set -g status-right-length 50
      setw -g clock-mode-colour default
    '';
  };
}
