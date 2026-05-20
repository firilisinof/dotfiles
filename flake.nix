{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";

    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
      nix-homebrew,
      home-manager,
      ...
    }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#birkin
      darwinConfigurations."birkin" = nix-darwin.lib.darwinSystem {
        modules = [
          ./configuration.nix
          ./brew.nix
          ./home.nix
        ];
        specialArgs = { inherit inputs; };
      };
    };
}
