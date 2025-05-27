# Anydesk remote desktop software
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.anydesk
  ];
}