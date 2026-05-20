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
      ...
    }:
    let
      user = {
        name = "lucas";
        fullName = "Lucas de Sousa Rosa";
        email = "roses.lucas404@gmail.com";
        home = "/Users/lucas";
      };
      host = {
        name = "birkin";
        system = "aarch64-darwin";
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#birkin
      darwinConfigurations.${host.name} = nix-darwin.lib.darwinSystem {
        modules = [ ./hosts/birkin ];
        specialArgs = { inherit inputs user host; };
      };
    };
}
