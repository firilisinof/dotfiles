{ ... }:

{
  imports = [ ../../modules/darwin/default.nix ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "kanjiro";
  networking.localHostName = "kanjiro";
  system.primaryUser = "lucas";
  users.users.lucas.home = "/Users/lucas";
  system.stateVersion = 6;

  home-manager.extraSpecialArgs.dotfilesDirectory = "/Users/lucas/Pessoal/dotfiles";

  home-manager.users.lucas = {
    imports = [ ../../modules/darwin/home.nix ];
    home.username = "lucas";
    home.homeDirectory = "/Users/lucas";
    home.stateVersion = "26.05";
  };
}
