# TODO move to home-manager
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.telegram-desktop
  ];
}
