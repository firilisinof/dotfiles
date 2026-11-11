{
  config,
  lib,
  pkgs,
  ...
}:

# a remote MCP shell, after github.com/stepbrobd/inc/blob/master/modules/nixos/mcp.nix.
# Kanidm issues each app its own issuer and token audience, and the server
# accepts one of each, so every app gets its own client, hostname and instance.
# Codex and Claude Code run on the Mac and reach the pi5 over SSH instead.
let
  user = "lucas";
  domain = "firilisinof.com";
  issuerOrigin = "https://auth.${domain}";
  socketDir = "/run/mcp";
  scope = "mcp:shell";

  apps = {
    claude = {
      displayName = "Claude";
      redirect = "https://claude.ai/api/mcp/auth_callback";
    };
    chatgpt = {
      displayName = "ChatGPT";
      # each ChatGPT connector has its own callback, shown in its OAuth settings
      redirect = "https://chatgpt.com/connector/oauth/6Ifrwiif6ngv";
    };
  };

  client = app: "mcp-${app}";
  host = app: "${app}.${domain}";
  socket = app: "${socketDir}/${app}.sock";
  secret = app: "kanidm/${client app}-secret";

  forApps = f: lib.mapAttrs' (app: a: lib.nameValuePair (client app) (f app a)) apps;
in
{
  dotfiles.tunnel.ingress = lib.mapAttrs' (
    app: _: lib.nameValuePair (host app) "unix:${socket app}"
  ) apps;
  dotfiles.tunnel.groups = [ "mcp" ];

  users.groups.mcp = { };
  # the sockets inherit the group of the directory
  systemd.tmpfiles.rules = [ "d ${socketDir} 2750 ${user} mcp -" ];

  # run the servers without a login session
  users.users.${user}.linger = true;

  sops.secrets = lib.mapAttrs' (
    app: _:
    lib.nameValuePair (secret app) {
      group = "kanidm";
      mode = "0440";
      restartUnits = [ "kanidm.service" ];
    }
  ) apps;

  services.kanidm.provision = {
    groups."mcp.users" = { };
    persons.${user}.groups = [ "mcp.users" ];
    systems.oauth2 = forApps (
      app: a: {
        inherit (a) displayName;
        originUrl = [ a.redirect ];
        originLanding = "https://${host app}/";
        basicSecretFile = config.sops.secrets.${secret app}.path;
        scopeMaps."mcp.users" = [
          "openid"
          scope
        ];
      }
    );
  };

  home-manager.users.${user} = {
    systemd.user.sockets = forApps (
      app: a: {
        Unit.Description = "MCP shell socket for ${a.displayName}";
        Socket = {
          ListenStream = socket app;
          SocketMode = "0660";
        };
        Install.WantedBy = [ "sockets.target" ];
      }
    );

    systemd.user.services = forApps (
      app: a: {
        Unit = {
          Description = "Authenticated MCP shell for ${a.displayName}";
          Requires = [ "${client app}.socket" ];
          After = [ "${client app}.socket" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.mcp;
          Environment = lib.mapAttrsToList (n: v: "${n}=${v}") {
            MCP_ISSUER = "${issuerOrigin}/oauth2/openid/${client app}";
            MCP_AUDIENCE = client app;
            MCP_RESOURCE = "https://${host app}/mcp";
            MCP_RESOURCE_METADATA_URL = "https://${host app}/.well-known/oauth-protected-resource/mcp";
            MCP_REQUIRED_SCOPE = scope;
            MCP_AUDIT_LOG = "%S/mcp/${app}.log";
            PATH = "/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin";
          };
          # the keys come from Kanidm through the tunnel, which may start later
          Restart = "on-failure";
          RestartSec = 5;
          StateDirectory = "mcp";
        };
        Install.WantedBy = [ "default.target" ];
      }
    );
  };
}
