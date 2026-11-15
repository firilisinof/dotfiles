{
  config,
  lib,
  pkgs,
  ...
}:

# the MCP service for the personal wiki, from github.com/firilisinof/wiki-mcp
# it owns the authoritative Git repository, and everything else in its state
# directory can be rebuilt from that repository
let
  user = "wiki-mcp";
  inherit (config.networking) domain;
  issuerOrigin = config.services.kanidm.server.settings.origin;
  client = "wiki-mcp";
  host = "wiki.${domain}";
  stateDirectory = "/var/lib/wiki-mcp";
  repository = "${stateDirectory}/wiki.git";
  socket = "/run/wiki-mcp/mcp.sock";
  secret = "kanidm/wiki-mcp-secret";
  githubKey = "wiki-mcp/github-key";
  githubRemote = "git@github.com:firilisinof/ai-wiki.git";
  scope = "wiki:memory";

  githubKnownHosts = pkgs.writeText "wiki-mcp-known-hosts" ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';
  gitSsh = pkgs.writeShellScript "wiki-mcp-ssh" ''
    exec ${lib.getExe' pkgs.openssh "ssh"} -F /dev/null \
      -i "$CREDENTIALS_DIRECTORY/github-key" \
      -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile=${githubKnownHosts} "$@"
  '';

  redirects = [
    "https://claude.ai/api/mcp/auth_callback"
    "https://chatgpt.com/connector/oauth/9pafN9BwjnlO"
  ];

  environment = {
    WIKI_MCP_GIT_DIR = repository;
    WIKI_MCP_STATE_DIR = "${stateDirectory}/index";
    WIKI_MCP_MODEL_DIR = "${pkgs.wiki-mcp.model}";
    WIKI_MCP_GIT_NAME = "wiki-mcp";
    WIKI_MCP_GIT_EMAIL = "wiki-mcp@${config.networking.hostName}";
  };

  # maintenance commands run as the service user with the service's storage settings
  maintenance = pkgs.writeShellScriptBin "wiki-mcp-maintenance" ''
    exec /run/wrappers/bin/sudo -u ${user} ${
      lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "${n}=${lib.escapeShellArg v}") environment)
    } ${lib.getExe pkgs.wiki-mcp} "$@"
  '';
in
{
  dotfiles.tunnel.ingress.${host} = "unix:${socket}";
  dotfiles.tunnel.groups = [ user ];

  dotfiles.monitors = [ { target = "https://${host}/.well-known/oauth-protected-resource"; } ];

  users.groups.${user} = { };
  users.users.${user} = {
    isSystemUser = true;
    group = user;
    home = stateDirectory;
  };

  environment.systemPackages = [ maintenance ];

  sops.secrets.${secret} = {
    group = "kanidm";
    mode = "0440";
    restartUnits = [ "kanidm.service" ];
  };

  sops.secrets.${githubKey}.restartUnits = [ "wiki-mcp.service" ];

  services.kanidm.provision = {
    groups."wiki-mcp.users" = { };
    persons.lucas.groups = [ "wiki-mcp.users" ];
    systems.oauth2.${client} = {
      displayName = "Wiki MCP";
      originUrl = redirects;
      originLanding = "https://${host}/";
      basicSecretFile = config.sops.secrets.${secret}.path;
      scopeMaps."wiki-mcp.users" = [
        "openid"
        scope
      ];
    };
  };

  systemd.services.wiki-mcp = {
    description = "Wiki MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = environment // {
      WIKI_MCP_PUSH_REMOTE = "origin";
      GIT_SSH_COMMAND = "${gitSsh}";
      WIKI_MCP_LISTEN = "unix:${socket}";
      WIKI_MCP_ISSUER = "${issuerOrigin}/oauth2/openid/${client}";
      WIKI_MCP_AUDIENCE = client;
      WIKI_MCP_REQUIRED_SCOPE = scope;
      WIKI_MCP_RESOURCE = "https://${host}/mcp";
      WIKI_MCP_RESOURCE_METADATA_URL = "https://${host}/.well-known/oauth-protected-resource/mcp";
      # embeddings share the four cores with every other service
      RAYON_NUM_THREADS = "2";
    };
    # an empty repository lets the service start before the wiki is imported
    preStart = ''
      if [ ! -d ${repository} ]; then
        ${lib.getExe pkgs.git} init --quiet --bare --initial-branch=main ${repository}
      fi
      ${lib.getExe pkgs.git} --git-dir=${repository} config remote.origin.url ${lib.escapeShellArg githubRemote}
    '';
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.wiki-mcp} serve";
      LoadCredential = [ "github-key:${config.sops.secrets.${githubKey}.path}" ];
      User = user;
      Group = user;
      StateDirectory = "wiki-mcp";
      StateDirectoryMode = "0750";
      RuntimeDirectory = "wiki-mcp";
      # the tunnel reaches the socket through the service group
      RuntimeDirectoryMode = "0750";
      UMask = "0027";
      # the keys come from Kanidm, which may start later
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };
  };

  # the index and the model are rebuilt from the repository and the package
  services.restic.backups.b2 = {
    paths = [ repository ];
    stopUnits = [ "wiki-mcp.service" ];
  };
}
