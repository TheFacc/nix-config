{
  description = "nixos config";

  inputs = {
    # NixOS package sources
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";#release-23.11"
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # NixOS hardware packages
    hardware.url = "github:nixos/nixos-hardware";
    
    # Home-manager for declaring user/home configurations
    home-manager = {
      url = "github:nix-community/home-manager";#/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # get MATLAB
    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Firefox addons
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Flatpak # TODO:
    # https://github.com/GermanBread/declarative-flatpak/blob/dev/docs/home-manager.md
    # or maybe
    # https://github.com/gmodena/nix-flatpak?tab=readme-ov-file
    # flatpak.url = "github:yawnt/declarative-nix-flatpak/main";
    # flatpaks.url = "github:GermanBread/declarative-flatpak/stable";

  };

  outputs = { self, nixpkgs, home-manager, nix-matlab, ... }@inputs:
  let
    inherit (self) outputs;
    lib = nixpkgs.lib // home-manager.lib;
    user = "facc"; #TODO not the right place here
    # system = "x86_64-linux";
    systems = [
      "x86_64-linux"
      # "aarch64-linux"
      # "x86_64-darwin"
      # "aarch64-darwin"
      # "i686-linux"
    ];
    forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
#     pkgs = import nixpkgs {
#       inherit system;
# #       config = {
# #         allowUnfree = true;
# #       };
#       overlays = flake-overlays;
#     };
    pkgsFor = lib.genAttrs systems (system: import nixpkgs {
      inherit system;
      # config.allowUnfree = true;
    });
    allowed-unfree-packages = [ # https://stackoverflow.com/questions/77585228/
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
      "vscode"
    ];
    system = "x86_64-linux";
    # flake-overlays = [
    #   nix-matlab.overlay
    # ];
  in
  {
    inherit lib allowed-unfree-packages; # TODO try to remove unfree here
    # Custom modules to enable special functionality for nixos or home-manager oriented configs.
    # nixosModules = import ./modules/nixos;
    # homeManagerModules = import ./modules/home-manager;

    # Custom modifications/overrides to upstream packages.
    overlays = import ./overlays { inherit inputs outputs; };

     #################### NixOS Configurations ####################
      #
      # Available through 'nixos-rebuild --flake .#hostname'
      # Typically adopted using 'sudo nixos-rebuild switch --flake .#hostname'
    nixosConfigurations = {
      "nixossone" = lib.nixosSystem {
          modules = [ ./hosts/nixossone ];
          specialArgs = { inherit inputs outputs; };
    #   "nixossone" = nixpkgs.lib.nixosSystem {
    #       modules = [
    #         ./hosts/dell-g16/configuration.nix #flake
    # # ./ssh.nix-overlays)
    #         ./modules# flake-overlays)
    #         home-manager.nixosModules.home-manager {
    #             home-manager.useGlobalPkgs = true;
    #             home-manager.useUserPackages = true;
    #             home-manager.users.${user} = import ./home/${user};
    #             home-manager.extraSpecialArgs = {
    #               inherit user system allowed-unfree-packages flake-overlays;
    #               # overlays = flake-overlays;  
    #             }; # to hm modules
    #           }
    #       ];
    #       specialArgs = {
    #         inherit inputs system allowed-unfree-packages user; # to nix modules
    #         # overlays = flake-overlays;
    #       };
    #     };
        };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#username@hostname'
#     homeConfigurations."${user}@nixos" = home-manager.lib.homeManagerConfiguration {
#       pkgs = nixpkgs.legacyPackages.${system};
#       #extraSpecialArgs = {inherit allowed-unfree-packages user;};
#       modules = [
#        # ./home-manager/users/${user}.nix
#         ./modules/home-manager
#         ./modules/home-manager/git.nix
#       ];
#     };
    #################### User-level Home-Manager Configurations ####################
    #
    # Available through 'home-manager --flake .#primary-username@hostname'
    # Typically adopted using 'home-manager switch --flake .#primary-username@hostname'

    homeConfigurations = {
      "facc@nixossone" = lib.homeManagerConfiguration {
        modules = [ ./home/facc/nixossone.nix ];
        pkgs = pkgsFor.x86_64-linux;
        extraSpecialArgs = { inherit inputs outputs; };
      };
    };
  };
}


# canonical form of a module fyi: https://nixos.wiki/wiki/NixOS_modules
# { config, ... }:
# {
#   imports = [
#   # ...
#   ];
#   options = {
#   #  ...
#   };
#   config = {
#   # ...
#   };
# }
