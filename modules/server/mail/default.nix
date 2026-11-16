{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.sops) placeholder;
  home = config.home-manager.users.lucas;
  # the nixpkgs build lacks two libraries its dependencies link against
  ortiePackage = pkgs.ortie.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [
      pkgs.libgit2
      pkgs.aws-lc
    ];
  });
  ortie = lib.getExe ortiePackage;
  tokens = "${home.xdg.stateHome}/ortie";
  # label and address of each Google account
  google = {
    personal = "roses.lucas404@gmail.com";
  };
  toml = pkgs.formats.toml { };
in
{
  # agents read and organize mail with himalaya, and ortie hands it the google access tokens
  home-manager.users.lucas = {
    home.packages = [
      pkgs.himalaya
      ortiePackage
    ];
    xdg.configFile."himalaya/config.toml".source = toml.generate "himalaya-config.toml" {
      accounts = lib.mapAttrs (name: email: {
        inherit email;
        default = name == "personal";
        gmail.auth.token.command = [
          ortie
          "token"
          "show"
          "-a"
          name
        ];
      }) google;
    };
  };

  sops.secrets."google/oauth-client-id" = { };
  sops.secrets."google/oauth-client-secret" = { };

  # the client id cannot come from a command, so the whole file is rendered
  sops.templates."ortie-config.toml" = {
    owner = "lucas";
    path = "${home.xdg.configHome}/ortie/config.toml";
    content = lib.concatStrings (
      lib.mapAttrsToList (name: email: ''
        [accounts.${name}]
        default = ${lib.boolToString (name == "personal")}
        client-id = "${placeholder."google/oauth-client-id"}"
        client-secret.raw = "${placeholder."google/oauth-client-secret"}"
        endpoints.authorization = "https://accounts.google.com/o/oauth2/v2/auth"
        endpoints.token = "https://oauth2.googleapis.com/token"
        scopes = ["https://mail.google.com/", "https://www.googleapis.com/auth/calendar"]
        extras.access_type = "offline"
        extras.prompt = "consent"
        extras.login_hint = "${email}"
        auto-refresh = true
        # rotating tokens stay out of sops and out of the backup
        storage.read.command = ["${lib.getExe' pkgs.coreutils "cat"}", "${tokens}/${name}"]
        storage.write.command = "umask 077 && ${lib.getExe' pkgs.coreutils "mkdir"} -p ${tokens} && ${lib.getExe' pkgs.coreutils "cat"} > ${tokens}/${name}.tmp && ${lib.getExe' pkgs.coreutils "mv"} ${tokens}/${name}.tmp ${tokens}/${name}"

      '') google
    );
  };
}
