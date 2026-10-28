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
          ];
        }
        inputs.determinate.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        inputs.sops-nix.darwinModules.sops
        self.darwinModules.cache
        self.darwinModules.home-manager
        self.darwinModules.homebrew
        self.darwinModules.sops
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
        inputs.sops-nix.nixosModules.sops
        { home-manager.users.lucas.imports = [ self.homeModules.lucas.default ]; }
        self.nixosModules.backup
        self.nixosModules.cache
        self.nixosModules.home-manager
        self.nixosModules.kanidm
        self.nixosModules.kavita
        self.nixosModules.sops
        self.nixosModules.webdav
      ];
    };
  };
}
