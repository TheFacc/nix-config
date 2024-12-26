# Play Jellyfin media with mpv
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.jellyfin-mpv-shim
  ];
}