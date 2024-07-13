{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.kdiskmark
  ];
}
