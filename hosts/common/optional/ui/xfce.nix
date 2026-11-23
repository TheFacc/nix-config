# XFCE on X11, for headless boxes that only need a desktop now and then (e.g. over RustDesk).
# Boots to the console; the desktop runs only while display-manager does:
#   sudo systemctl start display-manager   # LightDM logs facc straight into XFCE
#   sudo systemctl stop display-manager
# Rebuilds never start it (display-manager has restartIfChanged = false).
{ pkgs, lib, ... }:
{
  services.xserver = {
    enable = true;
    desktopManager.xfce = {
      enable = true;
      enableScreensaver = false;
    };
    displayManager.lightdm.enable = true;
    # Never blank: a blanked or DPMS-off screen shows black in RustDesk
    serverFlagsSection = ''
      Option "BlankTime" "0"
      Option "StandbyTime" "0"
      Option "SuspendTime" "0"
      Option "OffTime" "0"
    '';
  };
  # Its DPMS and lid/idle actions would fight the settings above
  environment.xfce.excludePackages = [ pkgs.xfce4-power-manager ];

  services.displayManager = {
    defaultSession = "xfce";
    autoLogin = {
      enable = true;
      user = "facc";
    };
  };

  # A display manager makes graphical.target the default, which starts it at boot
  systemd.defaultUnit = lib.mkForce "multi-user.target";
}
