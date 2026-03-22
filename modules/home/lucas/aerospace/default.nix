{ ... }:

{
  programs.aerospace = {
    enable = true;
    package = null;
    settings = {
      after-startup-command = [
        "exec-and-forget borders active_color=0xff7CE3B1 inactive_color=0xff78788b width=5.0"
      ];
      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer = {
          left = 8;
          right = 8;
          top = 8;
          bottom = 8;
        };
      };

      workspace-to-monitor-force-assignment = {
        "1" = "main";
        "2" = "main";
        "3" = "main";
        "4" = "main";
        "5" = "main";
        "6" = "secondary";
        "7" = "secondary";
        "8" = "secondary";
        "9" = "secondary";
        "10" = "secondary";
      };

      mode.main.binding = {
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";
        alt-7 = "workspace 7";
        alt-8 = "workspace 8";
        alt-9 = "workspace 9";
        alt-0 = "workspace 10";

        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";
        alt-shift-6 = "move-node-to-workspace 6";
        alt-shift-7 = "move-node-to-workspace 7";
        alt-shift-8 = "move-node-to-workspace 8";
        alt-shift-9 = "move-node-to-workspace 9";
        alt-shift-0 = "move-node-to-workspace 10";

        alt-f = "fullscreen";
        alt-shift-space = "layout floating tiling";
      };
      on-window-detected = [
        {
          "if" = {
            app-id = "com.bitwarden.desktop";
            app-name-regex-substring = "Bitwarden";
          };
          run = "layout floating";
        }
        {
          "if".app-id = "com.apple.finder";
          run = "layout floating";
        }
        {
          "if".app-id = "com.apple.systempreferences";
          run = "layout floating";
        }
        {
          "if".window-title-regex-substring = "Settings|Preferences";
          run = "layout floating";
        }
      ];
    };
  };
}
