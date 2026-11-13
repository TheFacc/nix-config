# Dux Shell, formerly Dank Material Shell (system-wide, nixpkgs module).
# Upstream rebranded to Dux Labs in 2.0; the CLI and user unit are still `dms`.
# After first boot, run `dms setup` once to deploy niri integration files under ~/.config/niri/dms/.
# Theming (matugen), audio wavelength (cava), system monitoring and clipboard are built in;
# calendar and VPN backends are detected at runtime, configure them in DMS settings.
{ lib, ... }:
{
  # Backend for the DMS power profile switcher; the shell's module stopped enabling it.
  services.power-profiles-daemon.enable = lib.mkDefault true;

  programs.dux-shell = {
    enable = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };
  };
}
