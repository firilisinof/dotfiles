{ inputs, pkgs, ... }:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.lucas =
      { pkgs, ... }:
      {
        home = {
          username = "lucas";
          homeDirectory = "/Users/lucas";

          packages = with pkgs; [
            curl
            wget
            git
            ripgrep
            nixfmt
          ];

          shell = {
            enableFishIntegration = true;
          };

          file = {
            ".config/ghostty/config".text = ''
              font-family = "RobotoMono Nerd Font Mono"
              font-size = 14
              window-padding-x = 8
              window-padding-y = 8
              macos-titlebar-style = native
            '';
          };

          stateVersion = "26.05";
        };

        programs = {
          home-manager.enable = true;

          git = {
            enable = true;
            settings = {
              alias = {
                st = "status --short --branch";
                last = "log -1 --stat";
              };
              init.defaultBranch = "main";
              pull.rebase = true;
              push.autoSetupRemote = true;
              rebase.autoStash = true;
              user = {
                name = "Lucas de Sousa Rosa";
                email = "roses.lucas404@gmail.com";
              };
            };
          };

          fzf = {
            enable = true;
            enableZshIntegration = true;
            defaultOptions = [
              "--height=40%"
              "--layout=reverse"
              "--border"
            ];
          };
        };
      };
  };
}
