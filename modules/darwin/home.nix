{
  config,
  pkgs,
  lib,
  dotfilesDirectory,
  ...
}:

let
  configs = ../../config;
  skills = config.lib.file.mkOutOfStoreSymlink "${dotfilesDirectory}/config/ai/skills";
in
{
  home.packages = import ../common/packages.nix { inherit pkgs; };
  xdg.enable = true;

  xdg.configFile = lib.mapAttrs (_: value: value // { force = true; }) {
    "git/config".text =
      builtins.replaceStrings
        [ "/opt/homebrew/bin/gh" "/opt/homebrew/bin/git-lfs" ]
        [ "${pkgs.gh}/bin/gh" "${pkgs.git-lfs}/bin/git-lfs" ]
        (builtins.readFile (configs + /git/config));
    "git/ignore".source = configs + /git/ignore;
    "gh/config.yml".source = configs + /gh/config.yml;
    "ghostty/config".source = configs + /ghostty/config;
    "zsh/environment.zsh".text =
      builtins.replaceStrings
        [ "path=(\n" ]
        [ "path=(\n  ${lib.escapeShellArg config.home.profileDirectory}/bin\n" ]
        (builtins.readFile (configs + /zsh/environment.zsh));
  };

  home.file = lib.mapAttrs (_: value: value // { force = true; }) {
    ".agents/skills".source = skills;
    ".claude/skills".source = skills;
    ".omp/agent/skills".source = skills;
    ".ssh/config".source = configs + /ssh/config;
    ".zshenv".source = configs + /zsh/zshenv;
    ".zprofile".source = configs + /zsh/zprofile;
    ".zshrc".text =
      builtins.replaceStrings
        [
          "/opt/homebrew/share/zsh-autosuggestions"
          "/opt/homebrew/share/zsh-syntax-highlighting"
        ]
        [
          "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions"
          "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting"
        ]
        (builtins.readFile (configs + /zsh/zshrc));
  };
}
