{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    aerospace = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    janky-borders = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };
    swipeaerospace = {
      url = "github:mediosz/homebrew-tap";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, ... }:
  let
    system = "aarch64-darwin";
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Lucass-MacBook-Pro
    darwinConfigurations = {
      "Lucass-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit self;
          inherit (inputs) homebrew-core homebrew-cask aerospace janky-borders swipeaerospace;
        };
        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          # Align homebrew taps config with nix-homebrew.
          ({ config, ... }: {
            homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
          })
        ];
      };
    };
  };
}
