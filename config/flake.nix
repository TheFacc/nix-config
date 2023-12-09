{
  description = "System flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
#    home-manager = {
#      url = github:nix-community/home-manager;
#      inputs.nixpkgs.follows = "nixpkgs";
#    };
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
#        ./fusuma.nix # Fusuma touchpad congif (TODO)
       ./audio.nix # all audio config
       ./onedrive.nix # OneDrive sync
       ./syncthing.nix # Syncthing sync
       ./vscode.nix # VSCode app and extensions
       ./vpn.nix # VPN
#       ./wireguard.nix # Wireguard
#       ./steam.nix # Steam
       ./vm.nix # Virtual machine
       ./docker.nix # lato oscuro
       ./orbslam3.nix # keep opencv+gtk2 in the system to prevent its deletion+rebuild every time
       ./matlab.nix
       ./sonarr.nix # Sonarr
       ./plex.nix # Plex player
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
