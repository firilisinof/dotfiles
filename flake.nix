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
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
      # only the nix-darwin module is used, which needs none of these
      inputs.nix.follows = "";
      inputs.determinate-nixd-aarch64-darwin.follows = "";
      inputs.determinate-nixd-aarch64-linux.follows = "";
      inputs.determinate-nixd-x86_64-linux.follows = "";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zotero-mcp.url = "github:54yyyu/zotero-mcp";
    # the remote MCP shell served from the pi5
    mcp = {
      url = "github:stepbrobd/inc?dir=pkgs/mcp";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
    things = {
      url = "github:stepbrobd/things";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.parts.follows = "flake-parts";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # only the vendor kernel package is used, so nixpkgs is not followed and the kernel comes from its cache
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
      inputs.argononed.follows = "";
      inputs.nixos-images.follows = "";
      inputs.flake-compat.follows = "";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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
