{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    nixfmt
    ripgrep
    nodejs
  ];
}
