{
  description = "Main system flake (not working yet hehe)";

  inputs = {
    nixpkgs = { url = "nixpkgs/nixos-23.11"; };
    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
      #inputs.nixpkgs.follows = "nixpkgs";
    };
#    home-manager = {
#      url = github:nix-community/home-manager;
#      inputs.nixpkgs.follows = "nixpkgs";
#    };
  };

  outputs = { self, nixpkgs, nix-matlab, ... }@inputs:
    let
      flake-overlays = [ nix-matlab.overlay ];
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./configuration.nix flake-overlays)
  #        ./home-manager.nix # HomeManager import and all its configs (TODO)
  #        home-manager.nixosModules.home-manager
  #        {
  #          home-manager = {
  #            useUserPackages = true;
  #            useGlobalPkgs = true;
  #            users.facc = ./home-manager/home.nix;
  #          };
  #        }
        ];
      };
    };
}
