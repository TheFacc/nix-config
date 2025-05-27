{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    nativeBuildInputs = [ pkgs.buildPackages.ntfs3g ];
    shellHook =
        ''
        sudo fdisk -l
        echo "Run 'sudo ntfsfix -d /dev/sdX' to fix the NTFS drive"
        '';
}
