{ config, ... }:

{
  # each host reads secrets/<hostname>.yaml, encrypted to it in .sops.yaml
  sops.defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
