# Dank Material Shell (system-wide, nixpkgs module).
# After first boot, run `dms setup` once to deploy niri integration files under ~/.config/niri/dms/.
# Theming (matugen), audio wavelength (cava), system monitoring and clipboard are built in;
# calendar and VPN backends are detected at runtime, configure them in DMS settings.
{ ... }:
{
  programs.dms-shell = {
    enable = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };
  };
}
