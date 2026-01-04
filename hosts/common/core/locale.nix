{ pkgs, lib, config, ... }:

let
  loc = "en_US.UTF-8";
in
{
#   time.timeZone = "Europe/Rome";
  services.automatic-timezoned.enable = true;

  i18n.defaultLocale = loc;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = loc;
    LC_IDENTIFICATION = loc;
    LC_MEASUREMENT = loc;
    LC_MONETARY = loc;
    LC_NAME = loc;
    LC_NUMERIC = loc;
    LC_PAPER = loc;
    LC_TELEPHONE = loc;
    LC_TIME = loc;
  };
}
