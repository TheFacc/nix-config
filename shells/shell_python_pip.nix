# https://discourse.nixos.org/t/pip-oserror-errno-30-read-only-file-system/16263/4

with (import <nixpkgs> {});
stdenv.mkDerivation {
  name = "pip-env";
  buildInputs = [
    # System requirements.
    readline
    # Python requirements (enough to get a virtualenv going).
    python39Full
    python39Packages.virtualenv
    python39Packages.pip
    python39Packages.setuptools
  ];
  shellHook = ''
    # Allow the use of wheels.
    SOURCE_DATE_EPOCH=$(date +%s)
    # Augment the dynamic linker path
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${R}/lib/R/lib:${readline}/lib
  '';
}
