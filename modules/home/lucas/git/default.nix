{ ... }:

{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      alias = {
        co = "checkout";
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
}
