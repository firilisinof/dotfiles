{
  description = "Personal macOS tools and Raspberry Pi 5 server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504";
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
    {
      nixpkgs,
      nixos-hardware,
      nix-darwin,
      home-manager,
      ...
    }:
    {
      darwinConfigurations.kanjiro = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/kanjiro/configuration.nix
          home-manager.darwinModules.home-manager
        ];
      };

      nixosConfigurations.pi5 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          nixos-hardware.nixosModules.raspberry-pi-5
          ./hosts/pi5/hardware-configuration.nix
          ./hosts/pi5/configuration.nix
        ];
      };
    };
}
