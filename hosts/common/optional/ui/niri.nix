# Base Niri compositor stack (system-level). Pair with programs.dms-shell.
{ config, pkgs, lib, ... }:
{
  programs.niri.enable = true;

  systemd.user.services.niri.enableDefaultPath = false;

  hardware.graphics.enable = true;

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    config.common.default = [ "gnome" ];
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time-format %I:%M%p --asterisks --remember --remember-user-session --cmd ${config.programs.niri.package}/bin/niri-session";
        user = "greeter";
      };
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WLONLY = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    grim
    slurp
  ];
}
