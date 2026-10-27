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
      pkgs.agent-browser
      pkgs.antigravity-cli
      pkgs.claude-code
      pkgs.codex
      pkgs.omp
    ];

    home.file = {
      ".agents/skills".source = skills;
      ".claude/skills".source = skills;
      ".omp/agent/skills".source = skills;
    };
  };
}
