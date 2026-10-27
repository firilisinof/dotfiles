{ ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    casks = [
      # retain TeX Live 2026 and its package manager
      "mactex-no-gui"
      # vendor installers manage privileged networking components
      "mullvad-vpn"
      "tailscale-app"
      # steam manages its mutable client and helper services
      "steam"
      # some bundled JAR signatures require extended attributes
      "vlc"
    ];
  };
}
