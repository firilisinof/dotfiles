{
  description = "Minimal Raspberry Pi 5 server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixos-hardware, ... }: {
    nixosConfigurations.pi5 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./modules/shared/packages.nix
        nixos-hardware.nixosModules.raspberry-pi-5
        ./hosts/pi5/hardware-configuration.nix
        ./hosts/pi5/configuration.nix
      ];
    };
  };
}
