{ ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.lucas = ../home/lucas;
  };
}
