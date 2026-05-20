{
  pkgs,
  lib,
  inputs,
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
      lucas ALL=(ALL:ALL) NOPASSWD:SETENV: ALL
    '';
    variables = {
      SSH_AUTH_SOCK = "/Users/lucas/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
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
    hostName = "birkin";
    computerName = "birkin";
    localHostName = "birkin";
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
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  programs = {
    fish.enable = true;
    man.enable = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = "lucas";
    startup.chime = false;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;
  };

  users.users.lucas = {
    home = "/Users/lucas";
    shell = pkgs.fish;
  };
}
