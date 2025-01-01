{ pkgs, lib, config, ... }:
{
  # Enable the KDE Plasma Desktop Environment.
  options = { # TODO set as if/else... https://discourse.nixos.org/t/mkif-vs-if-then/28521
    plasma5.enable = lib.mkEnableOption "plasma5";
    plasma6.enable = lib.mkEnableOption "plasma6";
  };

  config = {
    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # plasma5
    services.displayManager.sddm.enable = lib.mkIf config.plasma5.enable true;
    services.xserver.desktopManager.plasma5.enable = lib.mkIf config.plasma5.enable true;

    # plasma6
    # services.xserver.displayManager.sddm.wayland.enable = true; # avoid running X server
    services.desktopManager.plasma6.enable = lib.mkIf config.plasma6.enable true; 
    environment.plasma6.excludePackages = lib.mkIf config.plasma6.enable [
      pkgs.kdePackages.plasma-browser-integration
      # pkgs.kdePackages.konsole
      pkgs.kdePackages.oxygen
    ];
  };
}
