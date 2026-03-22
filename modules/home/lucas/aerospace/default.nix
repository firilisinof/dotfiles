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
        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";
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
      ];
    };
  };
}
