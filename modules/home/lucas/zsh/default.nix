{ config, lib, ... }:

let
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
    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      append = false;
      extended = false;
      expireDuplicatesFirst = false;
      findNoDups = false;
      ignoreAllDups = false;
      ignoreDups = true;
      ignoreSpace = true;
      saveNoDups = false;
      share = true;
    };
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
