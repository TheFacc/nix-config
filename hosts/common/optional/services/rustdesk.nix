# RustDesk remote desktop client
# https://wiki.nixos.org/wiki/RustDesk
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.rustdesk-flutter
  ];
}
