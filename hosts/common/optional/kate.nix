# KDE text editor

{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.kdePackages.kate
  ];
}
