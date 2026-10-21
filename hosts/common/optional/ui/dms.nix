# Dank Material Shell (system-wide, nixpkgs module).
# After first boot, run `dms setup` once to deploy niri integration files under ~/.config/niri/dms/.
# Theming (matugen), audio wavelength (cava), system monitoring and clipboard are built in;
# calendar and VPN backends are detected at runtime, configure them in DMS settings.
{ lib, ... }:
{
  # Backend for the DMS power profile switcher; the dms-shell module stopped enabling it.
  services.power-profiles-daemon.enable = lib.mkDefault true;

  programs.dms-shell = {
    enable = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };
  };
}
