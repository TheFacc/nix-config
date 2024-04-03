{ pkgs ? import <nixpkgs> {} }:

  pkgs.mkShell {

      nativeBuildInputs = with pkgs.buildPackages; [
        gcc11
        # cmake
        eigen
        #suitesparse
        muparser
        muparserx
        # trying to fix clang missing std headers:
        #llvmPackages_17.libcxxStdenv
        #libstdcxx5
      ];

    # not working: (would be too easy huh)
    #export mkPrefix=/home/facc/OneDrive/5.2_PACS/22-23/Labs24/u/sw/
    #source ${mkPrefix}/etc/profile
    #shellHook = ''
    #  source /u/sw/etc/profile
    #  module load gcc-glibc
    #  module load package_name
    #'';
  }
