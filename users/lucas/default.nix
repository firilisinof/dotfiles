{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./fish.nix
  ];

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
        theme = GitHub Light Default
        window-theme = light
      '';
      ".claude/CLAUDE.md".text = ''
        # Writing guidelines

        - Avoid em dashes and semicolons for splitting sentences.
        - Prefer shorter sentences separated by commas or dots.
      '';
    };

    stateVersion = "26.05";
  };

  programs = {
    home-manager.enable = true;
    man.generateCaches = false;
  };
}
