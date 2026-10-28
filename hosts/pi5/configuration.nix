{ pkgs, ... }:

{
  home-manager.users.lucas = {
    home.stateVersion = "26.05";
  };

  environment.systemPackages = [
    pkgs.git
    pkgs.ghostty.terminfo
  ];

  networking.hostName = "pi5";
  networking.useDHCP = false;
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };
  networking.firewall.enable = true;

  time.timeZone = "Europe/Paris";

  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.lucas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ4qki0FODBJfXYm23oCPW7WvNI7VWf+3JdUryWj3dU8 Mac SSH key"
    ];
  };
  security.sudo = {
    wheelNeedsPassword = false;
    execWheelOnly = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ "lucas" ];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.fstrim.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "256M";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # verified for NVMe and Wi-Fi, with CPU thermal and fan support still unresolved
  boot.kernelPackages = pkgs.linuxPackages;
  boot.loader.grub.enable = false;
  boot.loader.timeout = 5;
  boot.loader.generic-extlinux-compatible = {
    enable = true;
    configurationLimit = 10;
    useGenerationDeviceTree = true;
    # the existing SD root is mounted at /boot and keeps its original boot directory
    mirroredBoots = [ { path = "/boot/boot"; } ];
  };
  hardware.enableRedistributableFirmware = true;
  # the mainline device tree omits the status led, cpu temperature sensor, and fan
  hardware.deviceTree.overlays = [
    {
      name = "status-led-off";
      dtsFile = ./status-led.dtso;
    }
    {
      name = "fan";
      dtsFile = ./fan.dtso;
      # a substring match that skips the ovl-rp1 variant, which adds rp1 at runtime and has no rp1_gpio label
      filter = "rpi-5-b.dtb";
    }
  ];

  system.stateVersion = "26.11";
}
