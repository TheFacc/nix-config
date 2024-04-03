# { config, pkgs, lib, ... }:
# let
#     nix-matlab = {
#         # Recommended if you also override the default nixpkgs flake, common among
#         # nixos-unstable users:
#         #inputs.nixpkgs.follows = "nixpkgs";
#         url = "gitlab:doronbehar/nix-matlab";
#     };
# in
# {
#     nixpkgs.overlays = [
#         nix-matlab.overlay
#     ]:
# }
{ #TODO can it be more declarative?
    home.file.".config/matlab/nix.sh".text = ''
        INSTALL_DIR=$HOME/MATLAB
    '';
    # nixpkgs.overlays = [
    #     (
    #     final: prev: {
    #         # Your own overlays...
    #     }
    #     )
    # ] ++ flake-overlays;

    # let
    #     nix-matlab = import (builtins.fetchTarball {
    #         url = "https://gitlab.com/doronbehar/nix-matlab/-/archive/master/nix-matlab-master.tar.gz";
    #         sha256="sha256:0qhxl64jjckc5r2m1mdv8ww9bkdvzm0cc4qxgbsnlniw1xx65r3k";
    #         });
    # in [
    #     nix-matlab.overlay
    #         (
    #             final: prev: {
    #                 # Your own overlays...
    #             }
    #         )
    # ];
}