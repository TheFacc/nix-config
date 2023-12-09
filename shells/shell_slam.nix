{ pkgs ? import <nixpkgs> {} }:

let
# SERIOUSLY WRONG WAY:
#   pangolin = pkgs.pangolin.overrideAttrs (oldAttrs: {
#     version = "0.6";
#   });
#   eigen = pkgs.eigen.overrideAttrs (oldAttrs: {
#     version = "3.1.0";
#   });
#   opencv = pkgs.opencv.overrideAttrs (oldAttrs: {
#     version = "4.4.0";
#   });
# CORRECT WAY:
  # Forcing versions from github commit taken from https://lazamar.co.uk/nix-versions/
  # ...can't be more precise than that ;)
  # VSCode-with-extensions (needed for C++ extension to work!) # --> now using vscode.fhs... too much trouble nixing # --> actually dont mess with fhs if you can, just nix
#  vscodeWE = (pkgs.vscode-with-extensions.override {
#        vscodeExtensions = with pkgs.vscode-extensions; [
#              ms-vscode.cpptools
#              github.copilot
#            ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
#              {
#                name = "theme-monokai-pro-vscode"; # Filter Spectrum
#                publisher = "monokai";
#                version = "1.2.1";
#                sha256 = "tRMuAqI6zqjvOCoESbJfD4fjgnA93pQ06ppvPDuwceQ=";
#              }
#              {
#                name = "GitHub.copilot-labs";
#                publisher = "GitHub";
#                version = "0.14.884";
#                sha256 = "0000000000000000000000000000000000000000000000000000";
#              }
#              {
#                name = "eamodio.gitlens";
#                publisher = "gitkraken";
#                version = "2023.5.3005";
#                sha256 = "0000000000000000000000000000000000000000000000000000";
#              }
#              {
#                name = "MaximSaplin.cptx";
#                publisher = "MaximSaplin";
#                version = "0.0.8";
#                sha256 = "0000000000000000000000000000000000000000000000000000";
#              }
#            ];
#          }
#    );

  # gcc 13.2.0 - out-of-bounds "errors" in Sophus/Eigen compilation using gcc12+ (it was fine with gcc11), but still works
  pk3 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/517501bcf14ae6ec47efd6a17dda0ca8e6d866f9.tar.gz") {};

  # opencv 4.6.0 (+ flag to enable gtk2)
  pk1 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/79b3d4bcae8c7007c9fd51c279a8a67acfa73a2a.tar.gz") {};

  # eigen 3.4.0, pangolin 0.6
  pk2 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/1a1bd86756ca15f8bafdce4499d6a88089bec3b6.tar.gz") {};

  # python + numpy
#  my-python-packages = python-packages: with python-packages; [
#    numpy
    #(opencv4.override {enableGtk2 = true;} ) # either this or the package pk1 above (or both) work!!
#  ];
#  python-with-my-packages = pkgs.python310.withPackages my-python-packages;

in

  pkgs.mkShell {
    shellHook =
        ''
        echo "Entering the shell tailored to work with ORB-SLAM3 package."
        cd "/home/facc/OneDrive/5.2_PACS/22-23/Proj/SLAMoCaDO"
#        echo "Launching VSCode in project dir."
#        code .
        '';
    buildInputs = [
      (pk1.opencv4.override (old : { enableGtk2 = true; }))
      pk2.eigen
      pk2.pangolin
      pk3.gcc11
      pk3.cmake
      pk3.gnumake
      pk3.gdb
      pk3.boost #
      pk3.glew # (glew.h)
      pk3.libGLU # (glu.h)
      pk3.libGL # (gl.h)
      pk3.openssl # (md5.h)
#      python-with-my-packages
    ];
}

# extra stuff found somewhere (was a mkDerivation):
#  src = ./.;
#  doCheck = true;
#  nativeBuildInputs = [ pkgconfig ];
#  buildInputs = [ gtk2-x11 clang rapidjson ];
#  preBuild = ''
#    substituteAllInPlace src/themes_service.h --replace "include/rapidjson/document.h" "rapidjson/document.h"
#    substituteInPlace Makefile --replace "pkg-config --libs --cflags gtk+-2.0" "pkg-config --libs --cflags gtk+-2.0 RapidJSON"
#  '';
