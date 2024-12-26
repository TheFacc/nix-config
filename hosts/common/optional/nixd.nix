# nixd language server

{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.nixd
  ];
}
