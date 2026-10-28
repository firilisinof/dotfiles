{ ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "kanjiro";
  networking.localHostName = "kanjiro";
  system.primaryUser = "lucas";
  users.users.lucas.home = "/Users/lucas";
  system.stateVersion = 6;

  home-manager.users.lucas = {
    dotfiles.directory = "/Users/lucas/Pessoal/dotfiles";
    home.stateVersion = "26.05";
  };
}
