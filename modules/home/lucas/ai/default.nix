{
  config,
  lib,
  pkgs,
  ...
}:

let
  skills = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.directory}/skills";
in
{
  options.dotfiles.directory = lib.mkOption {
    type = lib.types.str;
    description = "Local checkout of this repository, linked so skill edits apply without a rebuild.";
  };

  config = {
    home.packages = [
      pkgs.antigravity-cli
      pkgs.claude-code
      pkgs.codex
      pkgs.omp
    ];

    home.file = {
      ".agents/skills".source = skills;
      ".codex/AGENTS.md".source = ./context.md;
      ".claude/CLAUDE.md".source = ./context.md;
      ".gemini/GEMINI.md".source = ./context.md;
      ".omp/agent/AGENTS.md".source = ./context.md;
      ".claude/skills".source = skills;
      ".omp/agent/skills".source = skills;
    };
  };
}
