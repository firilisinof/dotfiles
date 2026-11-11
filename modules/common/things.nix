{ config, pkgs, ... }:

let
  home = config.home-manager.users.lucas;
in
{
  # the Things 3 CLI talks to Things Cloud directly, so it works on the pi5 without the app
  home-manager.users.lucas.home.packages = [ pkgs.things ];

  sops.secrets."things/email" = { };
  sops.secrets."things/password" = { };

  # the file `things auth` would write after signing in
  sops.templates."things-auth.json" = {
    owner = "lucas";
    path = "${home.xdg.configHome}/things/auth.json";
    content = builtins.toJSON {
      email = config.sops.placeholder."things/email";
      password = config.sops.placeholder."things/password";
    };
  };
}
