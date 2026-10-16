# OneDrive: abraunegg/onedrive client, driven by OneDriveGUI (tray).
#
# Nix owns the binaries and the autostart; accounts and sync settings stay
# live. OneDriveGUI spawns `onedrive --monitor` per profile itself and
# rewrites each profile's `config` and `sync_list` on save, so those files
# must stay writable: don't manage them with xdg.configFile.
#
# First run: open the tray icon, "Create new profile", log in, pick the sync
# dir, then tick "Auto-sync" so the profile starts with the GUI.
# State lives in ~/.config/onedrive-gui (profiles) and
# ~/.config/onedrive/accounts/<account>/ (client config, sync_list, db).
{ lib, pkgs, ... }:
let
  # The GUI runs whatever `onedrive` is on PATH (client_bin_path default).
  onedrivegui = pkgs.symlinkJoin {
    name = "onedrivegui-wrapped";
    paths = [ pkgs.onedrivegui ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/onedrivegui --prefix PATH : ${lib.makeBinPath [ pkgs.onedrive ]}
    '';
    inherit (pkgs.onedrivegui) meta;
  };

  guiDefaults = pkgs.writeText "onedrive-gui-settings" ''
    [SETTINGS]
    start_minimized = True
  '';
in
{
  home.packages = [ pkgs.onedrive onedrivegui ];

  # Started by systemd rather than the GUI's own "autostart" checkbox, which
  # writes an XDG autostart entry niri doesn't run. Leave that box unticked.
  systemd.user.services.onedrivegui = {
    Unit = {
      Description = "OneDriveGUI (OneDrive sync in the tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${onedrivegui}/bin/onedrivegui";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Seed GUI defaults once; afterwards the settings window owns the file.
  home.activation.onedriveguiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/onedrive-gui/gui_settings"
    if [ ! -e "$f" ]; then
      run install -Dm644 ${guiDefaults} "$f"
    fi
  '';
}
