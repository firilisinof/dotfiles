{
  config,
  pkgs,
  ...
}:

let
  port = toString config.services.qbittorrent.torrentingPort;
in
{
  sops.secrets."airvpn/private-key" = {
    restartUnits = [ "wireguard-airvpn.service" ];
  };
  sops.secrets."airvpn/preshared-key" = {
    restartUnits = [ "wireguard-airvpn-peer-athebyne.service" ];
  };

  networking.wireguard.interfaces.airvpn = {
    interfaceNamespace = "torrents";
    privateKeyFile = config.sops.secrets."airvpn/private-key".path;
    mtu = 1320;
    ips = [
      "10.158.221.96/32"
      "fd7d:76ee:e68f:a993:8eef:66af:b9cf:f84d/128"
    ];
    peers = [
      {
        name = "athebyne";
        publicKey = "PyLCXAQT8KkM4T+dUsOQfn+Ub3pGxfGlxkIApuig+hk=";
        presharedKeyFile = config.sops.secrets."airvpn/preshared-key".path;
        endpoint = "86.106.84.164:1637";
        persistentKeepalive = 15;
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
      }
    ];
  };

  environment.etc."netns/torrents/resolv.conf".text = ''
    nameserver 10.128.0.1
    nameserver fd7d:76ee:e68f:a993::1
    options timeout:2 attempts:2
  '';

  systemd.services.wireguard-airvpn = {
    requires = [ "torrents-network.service" ];
    after = [ "torrents-network.service" ];
    bindsTo = [ "torrents-network.service" ];
    partOf = [ "torrents-network.service" ];
    unitConfig.ConditionPathExists = config.networking.wireguard.interfaces.airvpn.privateKeyFile;
  };

  systemd.services.torrents-network = {
    description = "Isolated torrent network with a private web interface";
    wantedBy = [ "multi-user.target" ];
    before = [
      "qbittorrent.service"
      "wireguard-airvpn.service"
    ];
    path = [
      pkgs.iproute2
      pkgs.nftables
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      ip netns add torrents
      ip -n torrents link set lo up
      ip link add torrent-host type veth peer name control netns torrents
      ip address add 10.200.0.1/30 dev torrent-host
      ip -n torrents address add 10.200.0.2/30 dev control
      ip netns exec torrents nft -f - <<'EOF'
      table inet torrents {
        chain input {
          type filter hook input priority 0; policy drop;
          ct state invalid drop
          iifname "lo" accept
          ct state established,related accept
          iifname "control" ip saddr 10.200.0.1 tcp dport 8080 accept
          iifname "airvpn" tcp dport ${port} accept
          iifname "airvpn" udp dport ${port} accept
        }
        chain output {
          type filter hook output priority 0; policy drop;
          oifname "lo" accept
          oifname "airvpn" accept
          oifname "control" ip daddr 10.200.0.1 tcp sport 8080 ct state established accept
        }
        chain forward {
          type filter hook forward priority 0; policy drop;
        }
      }
      EOF
      ip link set torrent-host up
      ip -n torrents link set control up
    '';
    # cleanup also runs when namespace creation succeeds but later setup fails
    postStop = ''
      if ip link show torrent-host >/dev/null 2>&1; then
        ip link delete torrent-host
      fi
      if test -e /run/netns/torrents; then
        ip netns delete torrents
      fi
    '';
  };
}
