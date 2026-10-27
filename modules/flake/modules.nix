{ lib, ... }:

let
  # each file or directory is one module, named without its .nix suffix
  modulesIn =
    dir:
    lib.mapAttrs' (name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (dir + "/${name}")) (
      builtins.readDir dir
    );

  # common modules work in both nix-darwin and NixOS, not in Home Manager
  common = modulesIn ../common;
in
{
  flake = {
    darwinModules = common // modulesIn ../darwin;
    nixosModules = common // modulesIn ../nixos;
    homeModules.lucas = modulesIn ../home/lucas;
  };
}
