{ user, ... }:
{
  programs.git = {
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
        name = user.fullName;
        email = user.email;
      };
    };
  };
}
