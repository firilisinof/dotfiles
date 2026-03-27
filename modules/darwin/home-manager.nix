{ self, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      flakeRoot = self.outPath;
    };
    users.lucas = ../home/lucas;
  };
}
