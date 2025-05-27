# Unified communications
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.beeper
  ];
}
