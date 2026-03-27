{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    claude-code
    codex
    gemini-cli
    nixfmt
    ripgrep
    nodejs
  ];
}
