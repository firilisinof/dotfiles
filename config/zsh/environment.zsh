# Shared by login and non-login shells; repeated sourcing is idempotent.
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
export WORDCHARS='*?_-.~=&;!#$%^(){}<>'

# Ghostty ships its terminal definitions independently of Nix.
export TERMINFO_DIRS="/Applications/Ghostty.app/Contents/Resources/terminfo:/usr/share/terminfo:"

typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.cargo/bin"
  /opt/homebrew/bin
  /opt/homebrew/sbin
  /Library/TeX/texbin
  $path
)
export PATH
