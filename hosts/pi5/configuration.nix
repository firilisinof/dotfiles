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

  # the Claude Code SSH remote uploads a generic glibc build of the cli
  programs.nix-ld.enable = true;

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

  # mainline with device tree overlays for the cpu sensor and gpio fan
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

  systemd.services.fan-schedule = {
    description = "Apply fan quiet hours without disabling thermal protection";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-udev-trigger.service"
      "time-sync.target"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      zone=
      for candidate in /sys/class/thermal/thermal_zone*; do
        if [[ $(cat "$candidate/type") == cpu-thermal ]]; then
          zone=$candidate
          break
        fi
      done
      if [[ -z $zone ]]; then
        echo "CPU thermal zone not found" >&2
        exit 1
      fi

      trip=
      for binding in "$zone"/cdev[0-9]*; do
        [[ -L $binding ]] || continue
        [[ $(cat "$binding/type") == gpio-fan ]] || continue
        index=$(cat "''${binding}_trip_point")
        if [[ $(cat "$zone/trip_point_''${index}_type") == active ]]; then
          trip="$zone/trip_point_''${index}_temp"
          break
        fi
      done
      if [[ -z $trip ]]; then
        echo "GPIO fan active trip not found" >&2
        exit 1
      fi

      case $(date +%H) in
        # THERMAL_TEMP_INVALID disables only this trip, not the thermal zone
        22|23|0[0-7]) temperature=-274000 ;;
        *) temperature=75000 ;;
      esac

      # bang_bang applies both trip removal and restoration immediately
      echo bang_bang > "$zone/policy"
      echo "$temperature" > "$trip"
      echo enabled > "$zone/mode"
    '';
  };

  systemd.timers.fan-schedule = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = [
        "*-*-* 08:00:00"
        "*-*-* 22:00:00"
      ];
      AccuracySec = "1s";
      Persistent = true;
    };
  };

  system.stateVersion = "26.11";
}
