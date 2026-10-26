{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      SuperMaquina = {
        HostName = "143.107.45.126";
        Port = 2031;
        User = "lsrosa";
      };
      ime = {
        HostName = "143.107.45.126";
        Port = 2031;
        ProxyJump = "roses.lucas@shell.ime.usp.br";
        User = "lsrosa";
      };
    };
  };
  home.file.".ssh/config".force = true;
}
