{
  pkgs,
  lib,
  inputs,
  user,
  host,
  ...
}:
{
  imports = [
    ../../modules/macos.nix
    ../../modules/home-manager.nix
    ./homebrew.nix
  ];

  environment = {
    etc."sudoers.d/10-passwordless".text = ''
      ${user.name} ALL=(ALL:ALL) NOPASSWD:SETENV: ALL
    '';
    variables = {
      SSH_AUTH_SOCK = "${user.home}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
    };
    profiles = [
      "$HOME/.nix-profile"
    ];
    shells = [ pkgs.fish ];
  };

  fonts.packages = [
    pkgs.roboto
    pkgs.nerd-fonts.roboto-mono
  ];

  networking = {
    hostName = host.name;
    computerName = host.name;
    localHostName = host.name;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      substituters = [
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };

  nixpkgs = {
    hostPlatform = host.system;
    config.allowUnfree = true;
  };

  programs = {
    fish.enable = true;
    man.enable = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system.activationScripts.postActivation.text = ''
    echo "Setting ${user.name}'s login shell to fish..."
    dscl . -create /Users/${user.name} UserShell ${pkgs.fish}/bin/fish
  '';

  system = {
    primaryUser = user.name;
    startup.chime = false;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;
  };

  users.users.${user.name} = {
    home = user.home;
    shell = pkgs.fish;
  };
}
