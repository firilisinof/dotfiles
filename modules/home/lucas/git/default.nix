{ ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      "*.swp"
      ".DS_Store"
    ];
    settings = {
      alias = {
        br = "branch";
        ci = "commit";
        co = "checkout";
        st = "status";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      user = {
        email = "roses.lucas404@gmail.com";
        name = "Lucas de Sousa Rosa";
      };
    };
  };
  xdg.configFile."git/config".force = true;
  xdg.configFile."git/ignore".force = true;
}
