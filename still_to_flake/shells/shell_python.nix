{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = python-packages: with python-packages; [
    pip
    numpy
  ];
  python-with-my-packages = pkgs.python310.withPackages my-python-packages;
/*  mach-nix = import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix";
    ref = "refs/tags/3.5.0";
  }) {};*/
in

  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = [
      python-with-my-packages
    ];
/*    mach-nix.mkPython {
      requirements = ''
        pillow
        numpy
        requests
      '';
    }*/

}
