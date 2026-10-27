{ ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "kanjiro";
  networking.localHostName = "kanjiro";
  system.primaryUser = "lucas";
  users.users.lucas.home = "/Users/lucas";
  system.stateVersion = 6;

  home-manager.users.lucas = { config, ... }: {
    dotfiles.directory = "/Users/lucas/Pessoal/dotfiles";
    home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${config.home.homeDirectory}/Applications/Home Manager Apps/Google Chrome.app/Contents/MacOS/Google Chrome";
    home.username = "lucas";
    home.homeDirectory = "/Users/lucas";
    home.stateVersion = "26.05";
  };
}
