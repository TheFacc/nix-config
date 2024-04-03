{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = [ pkgs.buildPackages.wineWowPackages.full ];
#     nativeBuildInputs = [ (import (builtins.fetchTarball {
#        url =
#          "https://github.com/NixOS/nixpkgs/archive/7342cdc70156522050ce813386f6e159ca749d82.tar.gz"; # 6.0.2
#           "https://github.com/NixOS/nixpkgs/archive/7ccb7b1d33ee13b98c539d8f8c5d10831cda6802.tar.gz"; # 8.0
#      }) { }).wineWowPackages.stable ];
}
