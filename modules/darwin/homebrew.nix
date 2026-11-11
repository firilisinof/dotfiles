{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
    brews = [
      "mas"
    ];
    casks = [
      "antigravity"
      "beeper"
      "chatgpt"
      "claude"
      "discord"
      "font-roboto"
      "font-roboto-condensed"
      "font-roboto-mono"
      "font-roboto-serif"
      "font-roboto-slab"
      "mactex-no-gui"
      "mullvad-vpn"
      "nextcloud"
      "obs"
      "obsidian"
      "osu"
      "steam"
      "tailscale-app"
      "visual-studio-code"
      "vlc"
      "zotero"
    ];
    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
      Numbers = 361304891;
      "uBlock Origin Lite" = 6745342698;
    };
  };
}
