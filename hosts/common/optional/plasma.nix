{ pkgs, lib, config, ... }:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  # plasma6
  services.displayManager.sddm.wayland.enable = true; # avoid running X server
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = [
    pkgs.kdePackages.plasma-browser-integration
    pkgs.kdePackages.oxygen
  ];
  # extra config from discourse 57808
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # mostly for games, that mostly still run on x11
#   services.displayManager.sddm.wayland.enable = true; # already above
  services.displayManager.defaultSession = "plasma";
}
