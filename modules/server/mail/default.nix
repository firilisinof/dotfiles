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
  # the first sign-in of an account, for a host without a browser
  googleLogin = pkgs.writers.writePython3Bin "google-login" { flakeIgnore = [ "E501" ]; } (
    builtins.replaceStrings [ "@ortie@" "@state@" ] [ ortie home.xdg.stateHome ] (
      builtins.readFile ./google-login.py
    )
  );
  tokens = "${home.xdg.stateHome}/ortie";
  # label and address of each Google account
  google = {
    personal = "roses.lucas404@gmail.com";
    drall = "drallmortal@gmail.com";
    usp = "roses.lucas@usp.br";
    ime = "roses.lucas@ime.usp.br";
  };
  toml = pkgs.formats.toml { };
  calendars = "${home.xdg.dataHome}/calendars";
  secretCommand =
    name:
    "${builtins.toJSON [
      "command"
      (lib.getExe' pkgs.coreutils "cat")
      config.sops.secrets.${name}.path
    ]}";
in
{
  # agents read and organize mail with himalaya and calendars with khal, and ortie holds the google sign-ins
  home-manager.users.lucas = {
    home.packages = [
      pkgs.himalaya
      pkgs.khal
      pkgs.vdirsyncer
      ortiePackage
      googleLogin
    ];
    # khal reads and writes local copies that vdirsyncer synchronizes with google
    xdg.configFile."vdirsyncer/config".text = ''
      [general]
      status_path = "${home.xdg.stateHome}/vdirsyncer/status/"
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: _: ''

        [pair ${name}]
        a = "${name}_local"
        b = "${name}_google"
        collections = ["from b"]
        conflict_resolution = "b wins"
        metadata = ["displayname", "color"]

        [storage ${name}_local]
        type = "filesystem"
        path = "${calendars}/${name}/"
        fileext = ".ics"

        [storage ${name}_google]
        type = "google_calendar"
        token_file = "${home.xdg.stateHome}/vdirsyncer/google-${name}.json"
        client_id.fetch = ${secretCommand "google/oauth-client-id"}
        client_secret.fetch = ${secretCommand "google/oauth-client-secret"}
      '') google
    );
    xdg.configFile."khal/config".text = ''
      [calendars]
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: _: ''
        [[${name}]]
        path = ${calendars}/${name}/*
        type = discover
      '') google
    )
    + ''

      [locale]
      timeformat = %H:%M
      dateformat = %Y-%m-%d
      longdateformat = %Y-%m-%d
      datetimeformat = %Y-%m-%d %H:%M
      longdatetimeformat = %Y-%m-%d %H:%M
      firstweekday = 0
    '';
    xdg.configFile."himalaya/config.toml".source = toml.generate "himalaya-config.toml" {
      # dates otherwise keep the offset of the sender's server
      envelope.list.datetime-local-tz = true;
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

  # vdirsyncer reads both as the user
  sops.secrets."google/oauth-client-id".owner = "lucas";
  sops.secrets."google/oauth-client-secret".owner = "lucas";

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
