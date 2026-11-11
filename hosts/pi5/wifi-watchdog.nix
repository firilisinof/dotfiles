{ pkgs, ... }:

{
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
}
