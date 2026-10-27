{
  config,
  lib,
  pkgs,
  ...
}:

let
  ollama = pkgs.callPackage ../../../../pkgs/darwin/ollama.nix { };
in
{
  # the package and launch agent are macOS only
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = [ ollama ];
    launchd.agents.ollama = {
      enable = true;
      config = {
        ProgramArguments = [
          "${ollama}/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = {
          OLLAMA_FLASH_ATTENTION = "1";
          OLLAMA_KV_CACHE_TYPE = "q8_0";
        };
        KeepAlive = true;
        RunAtLoad = true;
        WorkingDirectory = config.home.homeDirectory;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/ollama.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/ollama.log";
      };
    };
  };
}
