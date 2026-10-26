{ ... }:

{
  programs.gh = {
    enable = true;
    settings = {
      aliases = { };
      editor = "";
      git_protocol = "ssh";
    };
    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };
  };
  xdg.configFile."gh/config.yml".force = true;
}
