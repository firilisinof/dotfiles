{ config, lib, ... }:

let
  inherit (config.networking) domain;
  clients = {
    romm = "https://games.${domain}";
    ggrequestz = "https://requestz.${domain}";
  };
in
{
  sops.secrets = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "games/${name}-oidc-secret" {
      group = "kanidm";
      mode = "0440";
      restartUnits = [ "kanidm.service" ];
    }
  ) clients;
  services.kanidm.provision = {
    groups."games.admins" = { };
    persons.lucas.groups = [ "games.admins" ];
    systems.oauth2 = lib.mapAttrs (name: origin: {
      displayName = if name == "romm" then "Game library" else "Game requests";
      originLanding = "${origin}/";
      originUrl = "${origin}" + (if name == "romm" then "/api/oauth/openid" else "/api/auth/callback");
      basicSecretFile = config.sops.secrets."games/${name}-oidc-secret".path;
      allowInsecureClientDisablePkce = name == "ggrequestz";
      preferShortUsername = true;
      scopeMaps."games.admins" = [
        "openid"
        "email"
        "profile"
      ]
      ++ lib.optional (name == "romm") "games_role";
      claimMaps.games_role.valuesByGroup."games.admins" = [ "admin" ];
    }) clients;
  };
}
