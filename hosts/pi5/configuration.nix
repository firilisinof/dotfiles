{ config, pkgs, ... }:

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
  # u-boot selects the legacy -d filename, whose vendor tree uses the wrong pin controller
  hardware.deviceTree.dtbSource = pkgs.runCommand "pi5-device-trees" { } ''
    cp -rL ${config.boot.kernelPackages.kernel}/dtbs "$out"
    chmod u+w "$out/broadcom/bcm2712-d-rpi-5-b.dtb"
    cp "$out/broadcom/bcm2712d0-rpi-5-b.dtb" "$out/broadcom/bcm2712-d-rpi-5-b.dtb"
  '';
  system.checks = [
    (pkgs.runCommand "pi5-device-tree-check" { nativeBuildInputs = [ pkgs.dtc ]; } ''
      dtb=${config.hardware.deviceTree.package}/broadcom/bcm2712-d-rpi-5-b.dtb
      fdtget -t s "$dtb" /soc@107c000000/pinctrl@7d504100 compatible | grep -Fx brcm,bcm2712d0-pinctrl
      fdtget -t x "$dtb" /soc@107c000000/pinctrl@7d504100 reg | grep -Fx '7d504100 20'
      fdtget -t s "$dtb" /soc@107c000000/pinctrl@7d510700 compatible | grep -Fx brcm,bcm2712d0-aon-pinctrl
      fdtget -t x "$dtb" /soc@107c000000/pinctrl@7d510700 reg | grep -Fx '7d510700 1c'
      fdtget -t s "$dtb" /soc@107c000000/pinctrl@7d504100/wl_on_pins pins | grep -Fx gpio28
      fdtget -t s "$dtb" /cooling_fan status | grep -Fx okay
      fdtget -t s "$dtb" /axi/pcie@1000110000 status | grep -Fx okay
      touch "$out"
    '')
  ];
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
      interface=
      while IFS=: read -r device type; do
        if [[ $type == wifi ]]; then
          interface=$device
          break
        fi
      done < <(nmcli --terse --fields DEVICE,TYPE device status)
      if [[ -z $interface ]]; then
        echo "no Wi-Fi interface, leaving recovery to NetworkManager"
        exit 0
      fi

      route=$(ip -4 route show default dev "$interface")
      if [[ -z $route ]]; then
        echo "no default route on $interface, leaving recovery to NetworkManager"
        exit 0
      fi
      read -r _ _ gateway _ <<< "$route"

      failures_file=$RUNTIME_DIRECTORY/failures
      if ping -c 3 -W 2 -I "$interface" "$gateway" > /dev/null; then
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
      record ip -s link show dev "$interface"
      record ip -s neigh show dev "$interface"
      record ip route show dev "$interface"
      record iw dev "$interface" link
      record iw dev "$interface" station dump
      record nmcli device show "$interface"

      connection=$(nmcli --get-values GENERAL.CONNECTION device show "$interface")
      echo "reconnecting $connection"
      nmcli --wait 60 connection up "$connection" ifname "$interface"
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
