{ config, pkgs, ... }:

# matlab - https://gitlab.com/doronbehar/nix-matlab

{
 # users.users.facc = {
    nixpkgs.overlays = let
      nix-matlab = import (builtins.fetchTarball {
        url="https://gitlab.com/doronbehar/nix-matlab/-/archive/master/nix-matlab-master.tar.gz";
        #sha256="sha256:1drhcbg7j9qdfnnr8x5cmh8x7ys514n6a82gnlpv6i15yhk7mb6k";
      });
#      nix-matlab = import (builtins.fetchGit "https://gitlab.com/doronbehar/nix-matlab/-/archive/master/nix-matlab-master.tar.gz"){
#        url = "https://gitlab.com/doronbehar/nix-matlab";
#        ref = "refs/heads/master";
#        rev = "3f7f06ca4a234263f25898f8013605dbb644621e";
#      };
    in [
      nix-matlab.overlay ( final: prev: { } )
    ];
#  };
}
