# Dank Material Shell (system-wide, nixpkgs module).
# After first boot, run `dms setup` once to deploy niri integration files under ~/.config/niri/dms/.
{ lib, ... }:
{
  programs.dms-shell = {
    enable = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    # Plasma-adjacent QoL; trim for a lean VM.
    enableDynamicTheming = true;
    enableCalendarEvents = true;
    enableSystemMonitoring = true;
    enableAudioWavelength = true;
    enableVPN = lib.mkDefault false;
  };
}
