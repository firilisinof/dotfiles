{ pkgs, ... }:

let
  codexLoginSource = pkgs.fetchFromGitHub {
    owner = "firilisinof";
    repo = "account-switch";
    rev = "3dad6b8e705150310cce25f4cedb5833663eb931";
    hash = "sha256-ARoddzBcCnecQcj91N5nHaOW0crYyW2o1oMN63NiWmM=";
  };
  codexLogin = pkgs.callPackage (codexLoginSource + "/package.nix") { };
in
{
  home.packages = [
    pkgs.antigravity-cli
    pkgs.claude-code
    pkgs.codex
    codexLogin
  ];

  # every harness loads the same user-level instructions
  home.file = {
    ".claude/CLAUDE.md".source = ./context.md;
    ".codex/AGENTS.md".source = ./context.md;
    ".gemini/GEMINI.md".source = ./context.md;
  };
}
