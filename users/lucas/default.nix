{
  lib,
  pkgs,
  user,
  ...
}:
{
  imports = [
    ./git.nix
    ./fish.nix
  ];

  home = {
    username = user.name;
    homeDirectory = user.home;

    packages = with pkgs; [
      curl
      wget
      git
      git-lfs
      ripgrep
      nixfmt
      typst
      typstyle
    ];

    shell = {
      enableFishIntegration = true;
    };

    file.".config/ghostty/config".source = ./files/ghostty/config;

    # TODO: Find a better way to deal with these files.
    # Right now Codex and Claude doesn't support symbolic links properly.
    activation.aiFiles =
      let
        skillSoundLikeMe = ./files/ai/sound-like-me.md;
        aiFile = ./files/ai/AGENTS.md;
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.coreutils}/bin/install -d "${user.home}/.claude"
        ${pkgs.coreutils}/bin/install -d "${user.home}/.codex"
        ${pkgs.coreutils}/bin/install -d "${user.home}/.claude/skills/sound-like-me"
        ${pkgs.coreutils}/bin/install -d "${user.home}/.agents/skills/sound-like-me"

        ${pkgs.coreutils}/bin/rm -f "${user.home}/.claude/CLAUDE.md"
        ${pkgs.coreutils}/bin/rm -f "${user.home}/.codex/AGENTS.md"
        ${pkgs.coreutils}/bin/rm -f "${user.home}/.claude/skills/sound-like-me/SKILL.md"
        ${pkgs.coreutils}/bin/rm -f "${user.home}/.agents/skills/sound-like-me/SKILL.md"

        ${pkgs.coreutils}/bin/cp -f ${aiFile} "${user.home}/.claude/CLAUDE.md"
        ${pkgs.coreutils}/bin/cp -f ${aiFile} "${user.home}/.codex/AGENTS.md"
        ${pkgs.coreutils}/bin/cp -f ${skillSoundLikeMe} "${user.home}/.claude/skills/sound-like-me/SKILL.md"
        ${pkgs.coreutils}/bin/cp -f ${skillSoundLikeMe} "${user.home}/.agents/skills/sound-like-me/SKILL.md"
      '';

    stateVersion = "26.05";
  };

  programs = {
    home-manager.enable = true;
    man.generateCaches = false;

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
