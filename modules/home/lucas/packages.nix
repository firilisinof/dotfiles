{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    claude-code
    codex
    nixfmt
  ];
}
