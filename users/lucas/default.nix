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
      ripgrep
      nixfmt
      helix
    ];

    shell = {
      enableFishIntegration = true;
    };

    file.".config/ghostty/config".source = ./files/ghostty/config;

    # Trick avoid symlinks
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
    helix = {
      enable = true;

      settings = {
        theme = "github_light";
      };

      languages = {
        language = [
          {
            name = "nix";
            formatter.command = "nixfmt";
            auto-format = true;
          }
        ];
      };
    };
  };
}
