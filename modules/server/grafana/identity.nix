{ config, ... }:
let
  inherit (config.sops) secrets;
  auth = config.services.kanidm.server.settings.origin;
  origin = "https://home.${config.networking.domain}";
in
{
  sops.secrets."grafana/secret-key" = {
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
  };
  sops.secrets."grafana/oidc-secret" = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [
      "kanidm.service"
      "grafana.service"
    ];
  };
  systemd.services.grafana.serviceConfig.LoadCredential = [
    "oidc-secret:${secrets."grafana/oidc-secret".path}"
  ];
  services.kanidm.provision = {
    groups."grafana.admins" = { };
    persons.lucas.groups = [ "grafana.admins" ];
    systems.oauth2.grafana = {
      displayName = "Grafana";
      originLanding = "${origin}/";
      originUrl = "${origin}/login/generic_oauth";
      basicSecretFile = secrets."grafana/oidc-secret".path;
      preferShortUsername = true;
      scopeMaps."grafana.admins" = [
        "openid"
        "email"
        "profile"
      ];
    };
  };

  services.grafana.settings = {
    security = {
      secret_key = "$__file{${secrets."grafana/secret-key".path}}";
      disable_initial_admin_creation = true;
      cookie_secure = true;
    };
    # the home dashboard is readable on the tailnet and editors sign in with Kanidm
    "auth.anonymous" = {
      enabled = true;
      org_role = "Viewer";
    };
    auth.disable_login_form = true;
    "auth.basic".enabled = false;
    "auth.generic_oauth" = {
      enabled = true;
      name = "Kanidm";
      auto_login = true;
      client_id = "grafana";
      client_secret = "$__file{/run/credentials/grafana.service/oidc-secret}";
      scopes = "openid profile email";
      auth_url = "${auth}/ui/oauth2";
      token_url = "${auth}/oauth2/token";
      api_url = "${auth}/oauth2/openid/grafana/userinfo";
      use_pkce = true;
      allow_sign_up = true;
      login_attribute_path = "preferred_username";
      # Kanidm limits this client to the grafana.admins group
      role_attribute_path = "'Admin'";
    };
  };
}
