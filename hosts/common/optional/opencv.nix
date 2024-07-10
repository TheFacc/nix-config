# OpenCV + GTK enabled (SLAM development)

{ pkgs, ... }:
# let
#   # opencv 4.6.0
#   pk1 = import (fetchTarball {
#     url="https://github.com/NixOS/nixpkgs/archive/79b3d4bcae8c7007c9fd51c279a8a67acfa73a2a.tar.gz";
#     sha256="sha256:1lsrlgx4rg2wqxrz5j7kzsckgk4ymvr1l77rbqm1zxap6hg07dxf";
#     }) {};
# in
{
  environment.systemPackages = [
    (pkgs.opencv4.override (old : { enableGtk2 = true; }))
  ];
}
