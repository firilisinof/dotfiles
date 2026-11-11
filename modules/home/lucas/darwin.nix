{
  config,
  lib,
  pkgs,
  ...
}:

let
  jdk = pkgs.temurin-bin-21;
  # macOS resets the environment between the zsh startup files, so each one repeats it
  environment = ''
    export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    export TERMINFO_DIRS="${pkgs.ghostty-bin.terminfo}/share/terminfo:/usr/share/terminfo:"
  '';
in
{
  imports = [
    ./default.nix
    ./ghostty
    ./packages
    ./direnv
  ];

  home.file.".local/share/java/jdk21".source = "${jdk}";
  home.packages = [
    (pkgs.writeShellScriptBin "obsidian" ''
      exec /Applications/Obsidian.app/Contents/MacOS/obsidian-cli "$@"
    '')
    # preserve vendor signatures by skipping bundle fixups
    (pkgs.anki-bin.overrideAttrs { dontFixup = true; })
    pkgs.firefox-bin-unwrapped
    pkgs.google-chrome
  ];
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
}
