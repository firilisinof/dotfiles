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
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [
      pkgs.libgit2
      pkgs.aws-lc
    ];
  });
  ortie = lib.getExe ortiePackage;
  # the first sign-in of an account, for a host without a browser
  googleLogin = pkgs.writers.writePython3Bin "google-login" { flakeIgnore = [ "E501" ]; } (
    builtins.replaceStrings [ "@ortie@" ] [ ortie ] (builtins.readFile ./google-login.py)
  );
  tokens = "${home.xdg.stateHome}/ortie";
  # label and address of each Google account
  google = {
    personal = "roses.lucas404@gmail.com";
    drall = "drallmortal@gmail.com";
    usp = "roses.lucas@usp.br";
  };
  # the accounts whose calendars the views read, the first one receiving new events
  calendarAccounts = [
    "personal"
    "usp"
  ];
  gcal = pkgs.rustPlatform.buildRustPackage {
    pname = "gcal";
    version = "0.1.0";
    src = ./gcal;
    cargoLock.lockFile = ./gcal/Cargo.lock;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/gcal \
        --set-default GCAL_ORTIE ${ortie} \
        --set-default GCAL_TIME_ZONE ${config.time.timeZone} \
        --set-default GCAL_ACCOUNTS ${lib.concatStringsSep "," calendarAccounts}
    '';
    meta.mainProgram = "gcal";
  };
in
{
  # agents read and organize mail with himalaya and calendars with gcal, and ortie holds the google sign-ins
  home-manager.users.lucas = {
    home.packages = [
      pkgs.himalaya
      gcal
      ortiePackage
      googleLogin
    ];
  };

  sops.secrets."google/oauth-client-id" = { };
  sops.secrets."google/oauth-client-secret" = { };

  sops.templates."himalaya-config.toml" = {
    owner = "lucas";
    path = "${home.xdg.configHome}/himalaya/config.toml";
    content = ''
      # dates otherwise keep the offset of the sender's server
      envelope.list.datetime-local-tz = true

    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: email: ''
        [accounts.${name}]
        default = ${lib.boolToString (name == "personal")}
        email = "${email}"
        gmail.auth.token.command = ["${ortie}", "token", "show", "-a", "${name}"]

      '') google
    );
  };

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
