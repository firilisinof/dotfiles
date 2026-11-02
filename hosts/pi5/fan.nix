{
  # the mainline device tree omits the cpu temperature sensor and the gpio fan
  hardware.deviceTree.overlays = [
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

}
