{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# dynamic desktops amount and shortcuts:
# https://github.com/HeitorAugustoLN/nix-config/blob/752464c5ee50fc703654cff14b51f7437e458b3b/home/heitor/features/desktop/plasma/shortcuts.nix
{
  programs.plasma = {
    # Hotkeys: make shortcuts for commands
    hotkeys.commands = {
      launch-kitty = {
        name = "Launch Kitty";
        key = "Ctrl+Alt+T";
        command = "kitty";
      };
      launch-brave = {
        name = "Launch Brave";
        key = "Meta+Shift+B";
        command = "brave";
      };
      launch-telegram = {
        name = "Launch Telegram";
        key = "Meta+Shift+T";
        command = "Telegram";
      };
    };

    # Shortcuts: Plasma shortcuts e.g. changing desktops etc
    shortcuts = lib.mkMerge [
      {
        kwin = {
          "Switch One Desktop Up"   = "Ctrl+Meta+Up";
          "Switch One Desktop Down" = "Ctrl+Meta+Down";
          "Switch One Desktop to the Left"  = "Ctrl+Meta+Left";
          "Switch One Desktop to the Right" = "Ctrl+Meta+Right";

          "Switch to Next Screen" = "Meta+Alt+L";
          "Switch to Previous Screen" = "Meta+Alt+H";

          "Switch Window Up" = "Alt+K";
          "Switch Window Down" = "Alt+J";
          "Switch Window Left" = "Alt+H";
          "Switch Window Right" = "Alt+L";

          "Window Move Center" = "Meta+Shift+C";

          "Window One Desktop Up"   = "Ctrl+Meta+Shift+Up";
          "Window One Desktop Down" = "Ctrl+Meta+Shift+Down";
          "Window One Desktop to the Left"  = "Ctrl+Meta+Shift+Left";
          "Window One Desktop to the Right" = "Ctrl+Meta+Shift+Right";

          "Window Quick Tile Top"    = "Alt+Shift+Up";
          "Window Quick Tile Bottom" = "Alt+Shift+Down";
          "Window Quick Tile Left"   = "Alt+Shift+Left";
          "Window Quick Tile Right"  = "Alt+Shift+Right";

          "Window to Next Screen"     = "Meta+Shift+Right";
          "Window to Previous Screen" = "Meta+Shift+Left";

          "Walk Through Activities" = "Meta+Tab";
        };

        org_kde_powerdevil = {
          powerProfile = "Meta+B";
        };

        "services/org.kde.dolphin.desktop" = {
          _launch = "Meta+E";
        };
        "services/org.kde.krunner.desktop" = {
          _launch = builtins.concatStringsSep "\t" [
            "Alt+Space"
            "Search"
          ];
        };
      }
      { "plasmashell"."walk through activities" = "Meta+Tab"; }
      (lib.mkIf config.programs.brave.enable {
        "services/brave.desktop" = {
          new-window = "Meta+Alt+B";
        };
      })
      (lib.mkIf config.programs.konsole.enable {
        "services/org.kde.konsole.desktop" = {
          _launch = "Meta+Alt+T";
        };
      })
#       (lib.mkIf (builtins.elem myNeovim config.home.packages) {
#         "services/nvim.desktop" = {
#           _launch = "Meta+Alt+V";
#         };
#       })
    ];
  };
}
