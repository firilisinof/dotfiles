{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      pi5 = {
        HostName = "pi5.tail0a1230.ts.net";
        HostKeyAlias = "pi5";
        User = "lucas";
      };
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
}
