{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.treefmt.build.wrapper
          pkgs.age
          pkgs.sops
          pkgs.ssh-to-age
        ];
      };
    };
}
