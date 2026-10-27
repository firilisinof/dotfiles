{ inputs, self, ... }:

{
  flake = {
    darwinConfigurations.kanjiro = inputs.nix-darwin.lib.darwinSystem {
      modules = [
        ../../hosts/kanjiro/configuration.nix
        {
          home-manager.users.lucas.imports = with self.homeModules.lucas; [
            darwin
            ai
            ollama
          ];
        }
        inputs.home-manager.darwinModules.home-manager
        self.darwinModules.cache
        self.darwinModules.home-manager
        self.darwinModules.homebrew
        self.darwinModules.system
      ];
    };

    nixosConfigurations.pi5 = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-hardware.nixosModules.raspberry-pi-5
        ../../hosts/pi5/hardware-configuration.nix
        ../../hosts/pi5/configuration.nix
        { home-manager.users.lucas.imports = [ self.homeModules.lucas.default ]; }
        self.nixosModules.cache
        self.nixosModules.home-manager
      ];
    };
  };
}
