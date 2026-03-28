# Anydesk remote desktop software
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.anydesk
  ];

  services.displayManager = {
#   	autoLogin.enable = true;
#   	autoLogin.user = "facc";
    defaultSession = "plasmax11";
    sddm.wayland.enable = false;
  };
}