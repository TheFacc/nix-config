# facc on nixpad — niri + DMS
{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    common/core

    common/optional/desktops/catppuccin.nix
    common/optional/desktops/niri-desktop-binds.nix
    common/optional/ghostty.nix

    # Browsers
    common/optional/browsers/firefox.nix
    common/optional/browsers/brave.nix

    # Dev
    # common/optional/dev/vscode.nix
    # common/optional/dev/matlab.nix

    # Comms
    # common/optional/comms/telegram.nix

    # Services
    # common/optional/services/onedrive.nix

    # Entertainment
    ../common/optional/mpv.nix

    {
      home = {
        username = "facc";
        homeDirectory = "/home/facc";
      };
    }
  ];

  config = {
    nixpkgs.config = {
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
    };

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "kde";
      QT_STYLE_OVERRIDE = "Breeze";
    };

    home.pointerCursor = {
      enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    home.packages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kate
      kdePackages.kio-extras
      kdePackages.ark
      kdePackages.ffmpegthumbs
      kdePackages.breeze
      kdePackages.breeze-icons

      swappy
      # TODO drop the override once nixpkgs' hash matches again: upstream
      # re-uploaded the 26.1.052 tarball under the same URL
      (smartgit.overrideAttrs (old: {
        src = fetchurl {
          url = builtins.head old.src.urls;
          hash = "sha256-2KjUNabcN56cIBORN++YZlx2JuiuN/JMEDVjHo0wqw8=";
        };
      }))
    ];

    # DMS owns Niri's idle policy. Merge only these keys so its writable
    # settings file keeps the rest of the preferences made in the UI.
    home.activation.nixpadPower = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN_CMD:-}" ]; then
        settings_dir="${config.xdg.configHome}/DankMaterialShell"
        settings_file="$settings_dir/settings.json"
        ${pkgs.coreutils}/bin/mkdir -p "$settings_dir"
        if [ ! -e "$settings_file" ]; then
          ${pkgs.coreutils}/bin/printf '{}\n' > "$settings_file"
        fi
        settings_tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_dir/.settings.json.XXXXXX")"
        if ${pkgs.jq}/bin/jq -e '
          if type == "object" then . + {
            acMonitorTimeout: 600,
            acPostLockMonitorTimeout: 30,
            acSuspendTimeout: 0,
            batteryMonitorTimeout: 90,
            batteryPostLockMonitorTimeout: 20,
            batterySuspendTimeout: 0
          } else error("DMS settings must be an object") end
        ' "$settings_file" > "$settings_tmp"; then
          if ${pkgs.diffutils}/bin/cmp -s "$settings_tmp" "$settings_file"; then
            ${pkgs.coreutils}/bin/rm "$settings_tmp"
          else
            ${pkgs.coreutils}/bin/mv "$settings_tmp" "$settings_file"
          fi
        else
          ${pkgs.coreutils}/bin/rm -f "$settings_tmp"
          exit 1
        fi
      fi
    '';

    # Standalone KDE apps under Niri do not inherit Plasma's appearance
    # settings, so provide the small shared config files they read directly.
    xdg.configFile."kdeglobals" = {
      force = true;
      text = lib.generators.toINI { } {
        General = {
          ColorScheme = "BreezeDark";
          Name = "Breeze Dark";
        };
        Icons = {
          Theme = "breeze-dark";
        };
        KDE = {
          SingleClick = false;
        };
        "KFileDialog Settings" = {
          "Show Full Path" = true;
          "Show Inline Previews" = true;
          "Sort directories first" = true;
          "View Style" = "DetailTree";
        };
        PreviewSettings = {
          EnableRemoteFolderThumbnail = false;
          MaximumRemoteSize = 0;
        };
      };
    };

    xdg.configFile."kiorc" = {
      force = true;
      text = lib.generators.toINI { } {
        Confirmations = {
          ConfirmDelete = true;
          ConfirmEmptyTrash = true;
          ConfirmTrash = false;
        };
        "Executable scripts" = {
          behaviourOnLaunch = "alwaysAsk";
        };
      };
    };

    xdg.configFile."dolphinrc" = {
      force = true;
      # To make Dolphin settings properly declarative later: configure Dolphin
      # by hand on the real machine, then inspect the exact generated keys with:
      #   grep -n . ~/.config/dolphinrc ~/.config/kdeglobals ~/.config/kiorc
      # Copy only the settings you want to keep into this block.
      text = lib.generators.toINI { } {
        General = {
          BrowseThroughArchives = true;
          EditableUrl = true;
          ShowFullPath = true;
          ShowSelectionToggle = true;
        };
      };
    };

    # DMS shell settings workflow for the real machine:
    #   cp ~/.config/DankMaterialShell/settings.json /tmp/dms-settings-before.json
    #   cp ~/.config/DankMaterialShell/clsettings.json /tmp/dms-clsettings-before.json 2>/dev/null || true
    #   cp ~/.config/DankMaterialShell/plugin_settings.json /tmp/dms-plugin-settings-before.json 2>/dev/null || true
    # Then change settings in the DMS UI and inspect:
    #   diff -u /tmp/dms-settings-before.json ~/.config/DankMaterialShell/settings.json
    #   diff -u /tmp/dms-clsettings-before.json ~/.config/DankMaterialShell/clsettings.json
    #   diff -u /tmp/dms-plugin-settings-before.json ~/.config/DankMaterialShell/plugin_settings.json
    # Once the stable keys are known, add only those keys declaratively here,
    # or create a small dedicated DMS settings module.

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
      };
    };
  };
}
