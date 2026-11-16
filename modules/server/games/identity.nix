{ config, ... }:

let
  origin = "https://games.${config.networking.domain}";
in
{
  sops.secrets."games/romm-oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };
  services.kanidm.provision = {
    groups."games.admins" = { };
    persons.lucas.groups = [ "games.admins" ];
    systems.oauth2.romm = {
      displayName = "Game library";
      originLanding = "${origin}/";
      originUrl = "${origin}/api/oauth/openid";
      basicSecretFile = config.sops.secrets."games/romm-oidc-secret".path;
      preferShortUsername = true;
      scopeMaps."games.admins" = [
        "openid"
        "email"
        "profile"
        "games_role"
      ];
      claimMaps.games_role.valuesByGroup."games.admins" = [ "admin" ];
    };
  };
}
