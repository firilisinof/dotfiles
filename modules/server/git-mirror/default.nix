{
  config,
  lib,
  pkgs,
  ...
}:

# bare mirrors of upstream repositories, cloned with
# git clone lucas@pi5:/srv/git/<host>/<owner>/<name>.git
let
  user = "git-mirror";
  root = "/srv/git";
  sshKey = "git-mirror/ssh-key";
  schedule = "04:00";

  # https for public repositories, git@host:owner/name.git for private ones
  # a mirror is deleted when its URL leaves this list
  repositories = [
    "https://github.com/Djihads80/Eglantine.git"
    "https://github.com/FelipePrado0/SpartanPort.git"
    "https://github.com/ly05010419/MacNativeGames.git"
    "https://github.com/ProjectLeonida/Leonida.git"
    "https://github.com/riyadhHDA/wichforks.git"
    "https://github.com/seedds/nxnative.git"
    "https://github.com/slothic/d3hack.git"
    "https://github.com/truwa/nathan-drake-collection-macos.git"
    "https://github.com/valentderah/totk-pc-recomp.git"
    "https://github.com/Wooloomooloo2/bloodborne_mac_port.git"
    "https://github.com/zortos293/Lichii.git"
  ];

  knownHosts = pkgs.writeText "git-mirror-known-hosts" ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';
  gitSsh = pkgs.writeShellScript "git-mirror-ssh" ''
    exec ${lib.getExe' pkgs.openssh "ssh"} -F /dev/null \
      -i "$CREDENTIALS_DIRECTORY/ssh-key" \
      -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile=${knownHosts} "$@"
  '';
  mirror = pkgs.writers.writePython3 "git-mirror" {
    # ruff formats the script, and these are the checks it disagrees with
    flakeIgnore = [
      "E203"
      "E501"
      "W503"
    ];
  } (builtins.readFile ./mirror.py);
in
{
  users.groups.${user} = { };
  users.users.${user} = {
    isSystemUser = true;
    group = user;
  };
  # cloning over SSH reads the mirrors through the group
  users.users.lucas.extraGroups = [ user ];
  # the mirrors belong to the service user, which git otherwise refuses to serve
  programs.git = {
    enable = true;
    config.safe.directory = "${root}/*";
  };

  sops.secrets.${sshKey} = { };

  systemd.tmpfiles.rules = [ "d ${root} 2750 ${user} ${user} - -" ];

  systemd.services.git-mirror = {
    description = "Update the Git mirrors";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.git ];
    environment = {
      GIT_SSH_COMMAND = "${gitSsh}";
      GIT_TERMINAL_PROMPT = "0";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mirror} ${root} ${pkgs.writeText "git-mirror-repositories.json" (builtins.toJSON repositories)}";
      LoadCredential = [ "ssh-key:${config.sops.secrets.${sshKey}.path}" ];
      User = user;
      Group = user;
      UMask = "0027";
      Nice = 10;
      ReadWritePaths = [ root ];
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

  systemd.timers.git-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = schedule;
      Persistent = true;
    };
  };
}
