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
      "claude"
      "mactex-no-gui"
      "mullvad-vpn"
      "tailscale-app"
      "steam"
      "vlc"
    ];
  };
}
