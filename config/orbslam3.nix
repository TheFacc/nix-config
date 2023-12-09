{ config, pkgs, ... }:
let

  # opencv 4.6.0 + gtk2 enabled
  pk1 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/79b3d4bcae8c7007c9fd51c279a8a67acfa73a2a.tar.gz") {};

  # pangolin 0.6, eigen 3.4.0
#  pk2 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/1a1bd86756ca15f8bafdce4499d6a88089bec3b6.tar.gz") {};

  # gcc 13.2.0 + all others fixed in time
#  pk3 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/517501bcf14ae6ec47efd6a17dda0ca8e6d866f9.tar.gz") {};

in

{
  users.users.facc = {
    packages = with pkgs; [
      (pk1.opencv4.override (old : { enableGtk2 = true; }))
#      pk3.gnumake
#      pk3.gcc13
#      pk3.cmake
#      pk3.boost #
#      pk3.glew # (glew.h)
#      pk3.libGLU # (glu.h)
#      pk3.libGL # (gl.h)
#      pk3.openssl # (md5.h)
#      pk2.eigen
#      pk2.pangolin
#      python-with-my-packages      
    ];
  };
}
