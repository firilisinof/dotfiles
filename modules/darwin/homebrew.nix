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
      "antigravity"
      "anytype"
      "beeper"
      "chatgpt"
      "claude"
      "discord"
      "mactex-no-gui"
      "mullvad-vpn"
      "obs"
      "steam"
      "tailscale-app"
      "visual-studio-code"
      "vlc"
      "zotero"
    ];
  };
}
