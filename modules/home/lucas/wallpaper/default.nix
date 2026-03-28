{ config, flakeRoot, ... }:

let
  wallpaperName = "wallhaven-7j1q5e.jpg";
  wallpaperPath = "${config.home.homeDirectory}/Pictures/wallpapers/${wallpaperName}";
in
{
  home.file."Pictures/wallpapers/${wallpaperName}".source =
    flakeRoot + "/wallpapers/${wallpaperName}";

  launchd.agents.wallpaper = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          while ! /usr/bin/pgrep -x Dock >/dev/null || ! /usr/bin/pgrep -x WallpaperAgent >/dev/null; do
            /bin/sleep 1
          done

          /bin/sleep 2

          /usr/bin/osascript -e 'tell application "System Events" to set picture of every desktop to POSIX file "${wallpaperPath}"'
          /usr/bin/killall Dock || true
        ''
      ];
      RunAtLoad = true;
    };
  };
}
