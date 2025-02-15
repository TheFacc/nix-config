{ pkgs, lib, ... }:
{
  services.xserver = {
    # Enable the X11 windowing system.
    enable = true;
    # gnome
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # cleanup
  environment.gnome.excludePackages = (with pkgs; [
    atomix
    cheese
    epiphany
    geary
    gnome-music
    gnome-photos
    hitori
    iagno
    tali
    totem
  ]);
}
