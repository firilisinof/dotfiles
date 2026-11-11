{
  lib,
  pkgs,
  ...
}:

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
    ];

    home.file = {
      ".gemini/GEMINI.md".source = ./context.md;
    };
  };
}
