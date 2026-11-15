{
  config,
  lib,
  pkgs,
  ...
}:

# a remote MCP shell, after github.com/stepbrobd/inc/blob/master/modules/nixos/mcp.nix
# Claude and ChatGPT share one Kanidm client, so one issuer and audience, and
# one instance serves both.
# Codex and Claude Code run on the Mac and reach the pi5 over SSH instead.
let
  user = "lucas";
  inherit (config.networking) domain;
  issuerOrigin = config.services.kanidm.server.settings.origin;
  client = "mcp";
  host = "${client}.${domain}";
  socketDir = "/run/mcp";
  socket = "${socketDir}/mcp.sock";
  secret = "kanidm/mcp-secret";
  scope = "mcp:shell";

  redirects = [
    "https://claude.ai/api/mcp/auth_callback"
    # each ChatGPT connector has its own callback, shown in its OAuth settings
    "https://chatgpt.com/connector/oauth/6Ifrwiif6ngv"
  ];
in
{
  dotfiles.tunnel.ingress.${host} = "unix:${socket}";
  dotfiles.tunnel.groups = [ "mcp" ];

  users.groups.mcp = { };
  # the socket inherits the group of the directory
  systemd.tmpfiles.rules = [ "d ${socketDir} 2750 ${user} mcp -" ];

  # run the server without a login session
  users.users.${user}.linger = true;

  sops.secrets.${secret} = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };

  services.kanidm.provision = {
    groups."mcp.users" = { };
    persons.${user}.groups = [ "mcp.users" ];
    systems.oauth2.${client} = {
      displayName = "MCP";
      originUrl = redirects;
      originLanding = "https://${host}/";
      basicSecretFile = config.sops.secrets.${secret}.path;
      scopeMaps."mcp.users" = [
        "openid"
        scope
      ];
    };
  };

  home-manager.users.${user} = {
    systemd.user.sockets.mcp = {
      Unit.Description = "MCP shell socket";
      Socket = {
        ListenStream = socket;
        SocketMode = "0660";
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    systemd.user.services.mcp = {
      Unit = {
        Description = "Authenticated MCP shell";
        Requires = [ "mcp.socket" ];
        After = [ "mcp.socket" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.mcp;
        Environment = lib.mapAttrsToList (n: v: "${n}=${v}") {
          MCP_ISSUER = "${issuerOrigin}/oauth2/openid/${client}";
          MCP_AUDIENCE = client;
          MCP_RESOURCE = "https://${host}/mcp";
          MCP_RESOURCE_METADATA_URL = "https://${host}/.well-known/oauth-protected-resource/mcp";
          MCP_REQUIRED_SCOPE = scope;
          MCP_AUDIT_LOG = "%S/mcp/audit.log";
          PATH = "/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin";
        };
        # the keys come from Kanidm through the tunnel, which may start later
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "mcp";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
