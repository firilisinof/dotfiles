{ ... }:

{
  home.file.".config/ghostty/config".text = ''
    font-family = "FiraCode Nerd Font Mono"
    font-size = 14
    window-padding-x = 8
    window-padding-y = 8
    theme = GitHub Light Default
    window-theme = light
    macos-titlebar-style = native

    # Remove default tab/pane controls to keep Ghostty focused on terminal workflows.
    keybind = ctrl+shift+tab=unbind
    keybind = ctrl+tab=unbind
    keybind = super+digit_1=unbind
    keybind = super+1=unbind
    keybind = super+digit_2=unbind
    keybind = super+2=unbind
    keybind = super+digit_3=unbind
    keybind = super+3=unbind
    keybind = super+digit_4=unbind
    keybind = super+4=unbind
    keybind = super+digit_5=unbind
    keybind = super+5=unbind
    keybind = super+digit_6=unbind
    keybind = super+6=unbind
    keybind = super+digit_7=unbind
    keybind = super+7=unbind
    keybind = super+digit_8=unbind
    keybind = super+8=unbind
    keybind = super+9=unbind
    keybind = super+shift+[=unbind
    keybind = super+shift+]=unbind
    keybind = super+t=unbind
    keybind = super+alt+w=unbind
    keybind = super+d=unbind
    keybind = super+shift+d=unbind
    keybind = super+[=unbind
    keybind = super+]=unbind
    keybind = super+alt+arrow_up=unbind
    keybind = super+alt+arrow_down=unbind
    keybind = super+alt+arrow_left=unbind
    keybind = super+alt+arrow_right=unbind
    keybind = super+ctrl+arrow_up=unbind
    keybind = super+ctrl+arrow_down=unbind
    keybind = super+ctrl+arrow_left=unbind
    keybind = super+ctrl+arrow_right=unbind
        keybind = super+ctrl+equal=unbind
    keybind = super+shift+enter=unbind

    # Remove command-palette command entries so no tab/pane action icons are shown.
    command-palette-entry =
  '';
}
