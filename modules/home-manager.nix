{ inputs, user, ... }:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs user; };

    users.${user.name} = import ../users/lucas;
  };
}
