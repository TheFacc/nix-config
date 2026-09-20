{ pkgs, ... }:
let
  dms = "${pkgs.dms-shell}/bin/dms";
  dmsNiriConfig = builtins.readFile "${pkgs.dms-shell.src}/core/internal/config/embedded/niri.kdl";
  managedNiriConfig =
    let
      withFocusFollowsMouse = builtins.replaceStrings
        [ "    // focus-follows-mouse max-scroll-amount=\"0%\"" ]
        [ "    focus-follows-mouse max-scroll-amount=\"25%\"" ]
        dmsNiriConfig;
    in
    builtins.replaceStrings
      [ "            // layout \"us,ru\"" ]
      [ "            layout \"it\"" ]
      withFocusFollowsMouse;
  dolphin = "${pkgs.kdePackages.dolphin}/bin/dolphin";
  foot = "${pkgs.foot}/bin/foot";
  screenshotRegion = pkgs.writeShellScript "niri-screenshot-region-swappy" ''
    set -euo pipefail

    geometry="$(${pkgs.slurp}/bin/slurp)" || exit 0
    [ -n "$geometry" ] || exit 0

    ${pkgs.grim}/bin/grim -g "$geometry" - | ${pkgs.swappy}/bin/swappy -f -
  '';
  screenshotScreen = pkgs.writeShellScript "niri-screenshot-screen-swappy" ''
    set -euo pipefail

    ${pkgs.grim}/bin/grim - | ${pkgs.swappy}/bin/swappy -f -
  '';
in
{
  # Optional declarative Niri shortcuts for the DMS desktop.
  #
  # Import this module when you want Nix/Home Manager to own DMS's Niri binds.
  # Comment the import back out if you want to return to live DMS-generated
  # shortcut files while experimenting.
  #
  # The top-level config from `niri --default-config` contains stock inline
  # binds that win over DMS's included bind file. Use DMS's Niri template so
  # shortcuts are defined only through the included DMS files below.
  xdg.configFile."niri/config.kdl" = {
    force = true;
    text = managedNiriConfig;
  };

  # Niri's default cursor (and DMS "System Default") only has left_ptr, so
  # text / resize / pointer shapes never appear. Pin Adwaita, a complete theme.
  # DMS may rewrite this file if the cursor is changed in its Settings UI.
  xdg.configFile."niri/dms/cursor.kdl" = {
    force = true;
    text = ''
      cursor {
          xcursor-theme "Adwaita"
          xcursor-size 24
      }
    '';
  };

  # DMS's Niri config also includes "dms/layout.kdl". To declaratively tune
  # compositor-level appearance later, uncomment and adjust this block instead
  # of editing the generated file by hand. Useful knobs:
  # - gaps
  # - border.width
  # - focus-ring.width
  # - window-rule.geometry-corner-radius
  #
  # xdg.configFile."niri/dms/layout.kdl" = {
  #   force = true;
  #   text = ''
  #     layout {
  #         gaps 4
  #
  #         border {
  #             width 2
  #         }
  #
  #         focus-ring {
  #             width 2
  #         }
  #     }
  #
  #     window-rule {
  #         geometry-corner-radius 12
  #         clip-to-geometry true
  #         tiled-state true
  #         draw-border-with-background false
  #     }
  #   '';
  # };

  # DMS's Niri config includes "dms/binds.kdl", so this file replaces that
  # generated bind file when the module is enabled.
  xdg.configFile."niri/dms/binds.kdl" = {
    force = true;
    text = ''
      binds {
          // === Launchers & DMS surfaces ===
          Mod+Return hotkey-overlay-title="Open Terminal" { spawn "${foot}"; }
          Mod+T hotkey-overlay-title="Open Terminal" { spawn "${foot}"; }
          Mod+E hotkey-overlay-title="Open Dolphin" { spawn "${dolphin}"; }

          Mod+Space hotkey-overlay-title="Application Launcher" {
              spawn "${dms}" "ipc" "call" "spotlight" "toggle";
          }
          Mod+V hotkey-overlay-title="Clipboard History" {
              spawn "${dms}" "ipc" "call" "clipboard" "toggle";
          }
          Mod+A hotkey-overlay-title="Control Center" {
              spawn "${dms}" "ipc" "call" "control-center" "toggle";
          }
          Mod+N hotkey-overlay-title="Notification Center" {
              spawn "${dms}" "ipc" "call" "notifications" "toggle";
          }
          Mod+Comma hotkey-overlay-title="Settings" {
              spawn "${dms}" "ipc" "call" "settings" "focusOrToggle";
          }
          Mod+M hotkey-overlay-title="Task Manager" {
              spawn "${dms}" "ipc" "call" "processlist" "focusOrToggle";
          }
          Mod+X hotkey-overlay-title="Power Menu" {
              spawn "${dms}" "ipc" "call" "powermenu" "toggle";
          }
          Mod+Shift+N hotkey-overlay-title="Notepad" {
              spawn "${dms}" "ipc" "call" "notepad" "toggle";
          }
          Mod+Y hotkey-overlay-title="Browse Wallpapers" {
              spawn "${dms}" "ipc" "call" "dankdash" "wallpaper";
          }
          Mod+Shift+C hotkey-overlay-title="Color Picker" {
              spawn "${dms}" "ipc" "call" "color-picker" "toggle";
          }

          // Candidate emoji shortcut. Adjust the query once you find the
          // launcher syntax you like in DMS.
          // Mod+Period hotkey-overlay-title="Emoji Search" {
          //     spawn "${dms}" "ipc" "call" "spotlight" "toggleQuery" "emoji";
          // }

          // === Overview & help ===
          Mod+D repeat=false { toggle-overview; }
          Mod+Tab repeat=false { toggle-overview; }
          Mod+Shift+Slash { show-hotkey-overlay; }

          // === Security ===
          Mod+Alt+L hotkey-overlay-title="Lock Screen" {
              spawn "${dms}" "ipc" "call" "lock" "lock";
          }
          Mod+Shift+E { quit; }
          Ctrl+Alt+Delete hotkey-overlay-title="Task Manager" {
              spawn "${dms}" "ipc" "call" "processlist" "focusOrToggle";
          }

          // === Screenshots ===
          Print hotkey-overlay-title="Screenshot Region" {
              spawn "${screenshotRegion}";
          }
          Ctrl+Print hotkey-overlay-title="Screenshot Screen" {
              spawn "${screenshotScreen}";
          }
          Alt+Print { screenshot-window; }
          XF86Launch1 hotkey-overlay-title="Screenshot Region" {
              spawn "${screenshotRegion}";
          }
          Ctrl+XF86Launch1 hotkey-overlay-title="Screenshot Screen" {
              spawn "${screenshotScreen}";
          }
          Alt+XF86Launch1 { screenshot-window; }

          // === Audio controls ===
          XF86AudioRaiseVolume allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "audio" "increment" "3";
          }
          XF86AudioLowerVolume allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "audio" "decrement" "3";
          }
          XF86AudioMute allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "audio" "mute";
          }
          XF86AudioMicMute allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "audio" "micmute";
          }
          XF86AudioPause allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "playPause";
          }
          XF86AudioPlay allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "playPause";
          }
          XF86AudioPrev allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "previous";
          }
          XF86AudioNext allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "next";
          }
          Ctrl+XF86AudioRaiseVolume allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "increment" "3";
          }
          Ctrl+XF86AudioLowerVolume allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "mpris" "decrement" "3";
          }

          // === Brightness controls ===
          XF86MonBrightnessUp allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "brightness" "increment" "5" "";
          }
          XF86MonBrightnessDown allow-when-locked=true {
              spawn "${dms}" "ipc" "call" "brightness" "decrement" "5" "";
          }

          // === Window management ===
          Mod+Q repeat=false { close-window; }
          Mod+F { maximize-column; }
          Mod+Shift+F { fullscreen-window; }
          Mod+Shift+T { toggle-window-floating; }
          Mod+Shift+V { switch-focus-between-floating-and-tiling; }
          Mod+W { toggle-column-tabbed-display; }
          Mod+Shift+W hotkey-overlay-title="Create Window Rule" {
              spawn "${dms}" "ipc" "call" "window-rules" "toggle";
          }

          // === Focus navigation ===
          Mod+Left  { focus-column-left; }
          Mod+Down  { focus-window-down; }
          Mod+Up    { focus-window-up; }
          Mod+Right { focus-column-right; }
          Mod+H     { focus-column-left; }
          Mod+J     { focus-window-down; }
          Mod+K     { focus-window-up; }
          Mod+L     { focus-column-right; }

          // === Window movement ===
          Mod+Shift+Left  { move-column-left; }
          Mod+Shift+Down  { move-window-down; }
          Mod+Shift+Up    { move-window-up; }
          Mod+Shift+Right { move-column-right; }
          Mod+Shift+H     { move-column-left; }
          Mod+Shift+J     { move-window-down; }
          Mod+Shift+K     { move-window-up; }
          Mod+Shift+L     { move-column-right; }

          // === Column navigation ===
          Mod+Home { focus-column-first; }
          Mod+End  { focus-column-last; }
          Mod+Ctrl+Home { move-column-to-first; }
          Mod+Ctrl+End  { move-column-to-last; }

          // === Monitor navigation ===
          Mod+Ctrl+Left  { focus-monitor-left; }
          Mod+Ctrl+Right { focus-monitor-right; }
          Mod+Ctrl+H     { focus-monitor-left; }
          Mod+Ctrl+J     { focus-monitor-down; }
          Mod+Ctrl+K     { focus-monitor-up; }
          Mod+Ctrl+L     { focus-monitor-right; }

          // === Move to monitor ===
          Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
          Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
          Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
          Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
          Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
          Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
          Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
          Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

          // === Workspace navigation ===
          Mod+Page_Down { focus-workspace-down; }
          Mod+Page_Up   { focus-workspace-up; }
          Mod+U         { focus-workspace-down; }
          Mod+I         { focus-workspace-up; }
          Mod+Ctrl+Down { move-column-to-workspace-down; }
          Mod+Ctrl+Up   { move-column-to-workspace-up; }
          Mod+Ctrl+U    { move-column-to-workspace-down; }
          Mod+Ctrl+I    { move-column-to-workspace-up; }

          Ctrl+Shift+R hotkey-overlay-title="Rename Workspace" {
              spawn "${dms}" "ipc" "call" "workspace-rename" "open";
          }

          Mod+Shift+Page_Down { move-workspace-down; }
          Mod+Shift+Page_Up   { move-workspace-up; }
          Mod+Shift+U         { move-workspace-down; }
          Mod+Shift+I         { move-workspace-up; }

          // === Numbered workspaces ===
          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }

          Mod+Shift+1 { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }
          Mod+Shift+6 { move-column-to-workspace 6; }
          Mod+Shift+7 { move-column-to-workspace 7; }
          Mod+Shift+8 { move-column-to-workspace 8; }
          Mod+Shift+9 { move-column-to-workspace 9; }

          // === Column management ===
          Mod+BracketLeft  { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }
          Mod+Period { expel-window-from-column; }

          // === Sizing & layout ===
          Mod+R { switch-preset-column-width; }
          Mod+Shift+R { switch-preset-window-height; }
          Mod+Ctrl+R { reset-window-height; }
          Mod+Ctrl+F { expand-column-to-available-width; }
          Mod+C { center-column; }
          Mod+Ctrl+C { center-visible-columns; }

          Mod+Minus { set-column-width "-10%"; }
          Mod+Equal { set-column-width "+10%"; }
          Mod+Shift+Minus { set-window-height "-10%"; }
          Mod+Shift+Equal { set-window-height "+10%"; }

          // === Mouse wheel navigation ===
          Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
          Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
          Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
          Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

          Mod+WheelScrollRight      { focus-column-right; }
          Mod+WheelScrollLeft       { focus-column-left; }
          Mod+Ctrl+WheelScrollRight { move-column-right; }
          Mod+Ctrl+WheelScrollLeft  { move-column-left; }

          Mod+Shift+WheelScrollDown      { focus-column-right; }
          Mod+Shift+WheelScrollUp        { focus-column-left; }
          Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
          Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

          // === System controls ===
          Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
          Mod+Shift+P { power-off-monitors; }
      }
    '';
  };
}
