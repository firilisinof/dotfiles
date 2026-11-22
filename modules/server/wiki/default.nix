{ pkgs, ... }:

# agents work on the wiki as a plain Git checkout in ~/ws/ai-wiki, and Claude
# and ChatGPT reach that checkout through the MCP shell, as lucas
let
  sshKey = "lucas/ssh-key";
in
{
  # the Mac key from Bitwarden, which lets lucas push the wiki to GitHub
  sops.secrets.${sshKey} = {
    owner = "lucas";
    mode = "0400";
    path = "/home/lucas/.ssh/id_ed25519";
  };

  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  home-manager.users.lucas = {
    imports = [ ../../home/lucas/ai/wiki.nix ];
    home.packages = [ pkgs.ripgrep ];
  };
}
