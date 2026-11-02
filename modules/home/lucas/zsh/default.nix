{ config, lib, ... }:

let
  # path_helper on macOS puts the system directories first in every login shell,
  # so each startup file moves the user directories back to the front
  pathSetup = ''
    typeset -U path
    path=(${lib.escapeShellArgs config.home.sessionPath} $path)
    export PATH
  '';
in
{
  home.sessionPath = lib.mkBefore [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [ "history" ];
    };
    syntaxHighlighting.enable = true;
    shellAliases.ls = "eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions";
    envExtra = pathSetup + ''
      export WORDCHARS='*?_-.~=&;!#$%^(){}<>'
    '';
    profileExtra = lib.mkAfter pathSetup;
    initContent = lib.mkMerge [
      (lib.mkOrder 500 pathSetup)
      (lib.mkOrder 1000 "bindkey '^W' backward-kill-word")
    ];
  };
}
