# Persepolis download manager (~IDM)

{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.persepolis
  ];
}
