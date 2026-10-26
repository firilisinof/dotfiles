{
  config,
  lib,
  pkgs,
  dotfilesDirectory,
  ...
}:

let
  configs = ../../../config;
  skills = config.lib.file.mkOutOfStoreSymlink "${dotfilesDirectory}/config/ai/skills";
  environment = ''
    export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    export TERMINFO_DIRS="/Applications/Ghostty.app/Contents/Resources/terminfo:/usr/share/terminfo:"
  '';

in
{
  imports = [ ./default.nix ];
  home.packages = import ../../common/packages.nix { inherit pkgs; };
  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/Library/TeX/texbin"
  ];

  programs.zsh = {
    envExtra = lib.mkAfter environment;
    profileExtra = lib.mkBefore (
      ''
        eval "$(/opt/homebrew/bin/brew shellenv zsh)"
      ''
      + environment
    );
    initContent = lib.mkMerge [
      (lib.mkOrder 500 environment)
      (lib.mkOrder 550 "fpath=(/opt/homebrew/share/zsh/site-functions $fpath)")
      (lib.mkOrder 1000 ''
        if [[ -r "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration ]]; then
          source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
        fi
      '')
    ];
  };

  xdg.configFile."ghostty/config" = {
    source = configs + /ghostty/config;
    force = true;
  };
  home.file = lib.mapAttrs (_: value: value // { force = true; }) {
    ".agents/skills".source = skills;
    ".claude/skills".source = skills;
    ".omp/agent/skills".source = skills;
    ".ssh/config".source = configs + /ssh/config;
  };
}
