{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    curl
    wget
    claude-code
    codex
    nixfmt
  ];
}
