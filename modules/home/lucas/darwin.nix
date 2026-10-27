{
  config,
  lib,
  pkgs,
  dotfilesDirectory,
  ...
}:

let
  skills = config.lib.file.mkOutOfStoreSymlink "${dotfilesDirectory}/config/ai/skills";
  environment = ''
    export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    export TERMINFO_DIRS="${pkgs.ghostty-bin.terminfo}/share/terminfo:/usr/share/terminfo:"
  '';

in
{
  imports = [
    ./default.nix
    ./ghostty
  ];
  home.packages = (import ../../common/packages.nix { inherit pkgs; }) ++ [
    (pkgs.anki-bin.overrideAttrs { dontFixup = true; })
    pkgs.firefox-bin-unwrapped
    pkgs.google-chrome
    (pkgs.obsidian.overrideAttrs { dontFixup = true; })
  ];
  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${config.home.homeDirectory}/Applications/Home Manager Apps/Google Chrome.app/Contents/MacOS/Google Chrome";
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
    ];
  };

  programs.ssh.settings."*".IdentityAgent =
    "${config.home.homeDirectory}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

  home.file = {
    ".agents/skills".source = skills;
    ".claude/skills".source = skills;
    ".omp/agent/skills".source = skills;
  };
}
