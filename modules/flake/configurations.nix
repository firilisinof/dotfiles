{
  inputs,
  lib,
  self,
  ...
}:

{
  # every module under modules/darwin applies to kanjiro, and every module under modules/nixos to pi5
  flake = {
    darwinConfigurations.kanjiro = inputs.nix-darwin.lib.darwinSystem {
      modules = [
        inputs.determinate.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        inputs.sops-nix.darwinModules.sops
        ../../hosts/kanjiro/configuration.nix
        {
          home-manager.users.lucas.imports = with self.homeModules.lucas; [
            darwin
            ai
          ];
        }
      ]
      ++ lib.attrValues self.darwinModules;
    };

    nixosConfigurations.pi5 = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-hardware.nixosModules.raspberry-pi-5
        inputs.sops-nix.nixosModules.sops
        ../../hosts/pi5/configuration.nix
        { home-manager.users.lucas.imports = [ self.homeModules.lucas.default ]; }
      ]
      ++ lib.attrValues self.nixosModules;
    };
  };
}
