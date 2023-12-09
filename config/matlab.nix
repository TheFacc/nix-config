{ config, pkgs, ... }:

# matlab - https://gitlab.com/doronbehar/nix-matlab

{
  users.users.facc = {
    nixpkgs.overlays = let
      nix-matlab = import (builtins.fetchTarball "https://gitlab.com/doronbehar/nix-matlab/-/archive/master/nix-matlab-master.tar.gz");
    in [
      nix-matlab.overlay ( final: prev: { } )
    ];
}
