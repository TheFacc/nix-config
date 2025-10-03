{ inputs, ... }:
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager

    ./apps/konsole.nix # Terminal
    ./apps/kate.nix # Text editor
    ./apps/kcalc.nix # Calculator

    ./krunner.nix # KRunner
    ./kscreenlocker.nix # Screen locker
    ./kwin.nix # Effects, Night light, titlebar, virtual desktops
    ./panels.nix # Panels
    ./shortcuts.nix # Shortcuts
    ./theme.nix # Colorschemes, Cursors, Fonts, Icons, Sounds and Wallpaper.
    ./tiling.nix # Tiling

    ./input.nix # Touchpad
    ./power.nix # Power management
  ];

  programs.plasma = {
    enable = true;
    overrideConfig = true;

    windows = {
      allowWindowsToRememberPositions = true;
    };
    session = {
      sessionRestore.restoreOpenApplicationsOnLogin = "onLastLogout";
    };
  };
}
