{ lib, pkgs, ... }:

let
  skills = ../../../../skills;
  start = pkgs.writeShellApplication {
    name = "wiki-start";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${skills}/wiki/scripts/start.py "$@"
    '';
  };
in
{
  home.packages = [
    start
    pkgs.wiki-check
  ];
  home.file.".local/share/agent-workflows/skills".source = skills;
  home.file.".local/share/agent-workflows/wiki-start".source = "${start}/bin/wiki-start";
}
