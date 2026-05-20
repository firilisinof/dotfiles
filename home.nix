{ inputs, ... }:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.lucas = { ... }: {
      programs.home-manager.enable = true;
      home.stateVersion = "26.05";
      home.username = "lucas";
      home.homeDirectory = "/Users/lucas";
    };
  };
}
