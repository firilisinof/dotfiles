{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./fan.nix
  ];

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

  # the Claude Code SSH remote uploads a generic glibc build of the cli
  programs.nix-ld.enable = true;

  services.fstrim.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "256M";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  # the vendor kernel from nixos-raspberrypi
  nix.settings.substituters = [ "https://nixos-raspberrypi.cachix.org?priority=30" ];
  nix.settings.trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # the vendor kernel and its device tree come from modules/flake/configurations.nix
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
  # the vendor device tree flashes the status led on sd card activity
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="ACT", ATTR{trigger}="heartbeat"
  '';

  # a stalled link stays associated, so NetworkManager does not reconnect by itself
  systemd.services.wifi-watchdog = {
    description = "Reconnect Wi-Fi when the gateway stops answering";
    after = [ "NetworkManager.service" ];
    path = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.iw
      pkgs.networkmanager
    ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "wifi-watchdog";
      RuntimeDirectoryPreserve = true;
    };
    script = ''
      route=$(ip -4 route show default dev wlan0)
      if [[ -z $route ]]; then
        echo "no default route on wlan0, leaving recovery to NetworkManager"
        exit 0
      fi
      read -r _ _ gateway _ <<< "$route"

      failures_file=$RUNTIME_DIRECTORY/failures
      if ping -c 3 -W 2 -I wlan0 "$gateway" > /dev/null; then
        if [[ -e $failures_file ]]; then
          echo "gateway $gateway is answering again"
          rm "$failures_file"
        fi
        exit 0
      fi

      failures=$(($(cat "$failures_file" 2> /dev/null || echo 0) + 1))
      echo "gateway $gateway is not answering, failure $failures of 3"
      if ((failures < 3)); then
        echo "$failures" > "$failures_file"
        exit 0
      fi
      echo 0 > "$failures_file"

      record() {
        echo "+ $*"
        "$@" 2>&1 || echo "exit status $?"
      }
      record ip -s link show dev wlan0
      record ip -s neigh show dev wlan0
      record ip route show dev wlan0
      record iw dev wlan0 link
      record iw dev wlan0 station dump
      record nmcli device show wlan0

      connection=$(nmcli --get-values GENERAL.CONNECTION device show wlan0)
      echo "reconnecting $connection"
      nmcli --wait 60 connection up "$connection" ifname wlan0
    '';
  };

  systemd.timers.wifi-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitInactiveSec = "1min";
      AccuracySec = "5s";
    };
  };

  system.stateVersion = "26.11";
}
