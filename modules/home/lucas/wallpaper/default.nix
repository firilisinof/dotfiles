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
        "/usr/bin/osascript"
        "-e"
        ''
          tell application "System Events"
            set picture of every desktop to POSIX file "${wallpaperPath}"
          end tell
        ''
      ];
      RunAtLoad = true;
    };
  };
}
