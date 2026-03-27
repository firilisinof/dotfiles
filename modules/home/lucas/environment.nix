{ config, ... }:

{
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
  };
}
