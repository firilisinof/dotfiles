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
          home-manager.users.lucas.home.packages = [
            inputs.zotero-mcp.packages.aarch64-darwin.default
          ];
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
        {
          # the vendor kernel has the rp1 pwm driver that the fan curve needs
          boot.kernelPackages = inputs.nixos-raspberrypi.packages.aarch64-linux.linuxPackages_rpi5;
          # it comes from the stable nixpkgs of nixos-raspberrypi, whose kernel lacks the attributes behind these defaults
          system.boot.loader.kernelFile = "Image";
          hardware.deviceTree.enable = true;
          # the vendor kernel has no tpm-crb module, and the pi has no tpm
          boot.initrd.systemd.tpm2.enable = false;
        }
      ]
      ++ lib.attrValues self.nixosModules;
    };
  };
}
