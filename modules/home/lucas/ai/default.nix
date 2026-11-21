{ pkgs, ... }:

{
  home.packages = [
    pkgs.antigravity-cli
    pkgs.claude-code
    pkgs.codex
    pkgs.codex-login
    # the wiki's pre-commit hook
    pkgs.wiki-check
  ];

  # every harness loads the same user-level instructions
  home.file = {
    ".claude/CLAUDE.md".source = ./context.md;
    ".codex/AGENTS.md".source = ./context.md;
    ".gemini/GEMINI.md".source = ./context.md;
  };
}
