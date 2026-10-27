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

  home-manager.users.lucas = { config, ... }: {
    imports = [
      ../../modules/home/lucas/darwin.nix
      ../../modules/home/lucas/ai
    ];
    home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${config.home.homeDirectory}/Applications/Home Manager Apps/Google Chrome.app/Contents/MacOS/Google Chrome";
    home.username = "lucas";
    home.homeDirectory = "/Users/lucas";
    home.stateVersion = "26.05";
  };
}
