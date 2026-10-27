{
  description = "Personal macOS tools and Raspberry Pi 5 server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/triplet";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    autopilot = {
      url = "github:stepbrobd/autopilot";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.autopilot.lib.mkFlake
      {
        inherit inputs;
        # every entry in modules/flake is a flake-parts module
        autopilot.parts.path = ./modules/flake;
      }
      {
        systems = import inputs.systems;
      };
}
