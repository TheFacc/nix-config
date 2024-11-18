# RAR support

{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.rar
    pkgs.unrar
  ];
}
