{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz";
in
{
  # IMPORT
  # The following import will introduce a new NixOS option called home-manager.users
  # whose type is an attribute set that maps user names to Home Manager configurations.
  imports = [ (import "${home-manager}/nixos") ];

  # CONFIG
  #users.users.facc.extraGroups = [ "input" ];
  home-manager.users.facc = {
    /* The home.stateVersion option does not have a default and must be set */
    home.stateVersion = "23.11";

    # - Git
    programs.git = {
      enable = true;
      extraConfig = {
        "user.TheFacc" = {
          name = "TheFacc";
          email = "imthefacc@gmail.com";
        };
        "user.AFLux" = {
          name = "Alessio Facincani";
          email = "alessio.facincani@ext.luxottica.com";
        };
      };
    };
    home.packages = with pkgs; [ # additional packages
      # git
      github-desktop
      gh
    ];

    # - SSH
    programs.ssh = {
      enable = true;
      extraConfig = ''
        #github account
        Host *.github.com
          HostName github.com
          User TheFacc
          IdentityFile ~/.ssh/id_rsa

        #lux account
        Host *.google.com
          HostName source.developers.google.com
          User alessio.facincani@ext.luxottica.com
          IdentityFile ~/.ssh/id_rsa_lux
      '';
    };

    # - VSCode
#    programs.vscode = {
#      enable = true;
#      extensions = with pkgs.vscode-extensions; [
#        # Theme
##        monokai.theme-monokai-pro-vscode # -> Filter Spectrum
#        # C++
#        ms-vscode.cpptools
#        ms-vscode.cpptools-extension-pack
##        ms-vscode.cpptools-themes #kinda broken
#        twxs.cmake
#        ms-vscode.cmake-tools
#      ];
#    };

    # - Fusuma touchpad stuff
    # home.packages = with pkgs; [
    #   libinput
    #   fusuma
    #   xdotool
    # ];
    # services.fusuma = {
    #   enable = true;
    #   #extraPackages = with pkgs; [ xdotool ];
    #   settings = {
    #     swipe = {
    #         "3" = {
    #            left = {
    #              sendkey = "LEFTALT+RIGHT"; # History forward
    #            };
    #            right = {
    #              sendkey = "LEFTALT+LEFT"; # History back
    #            };
    #            up = {
    #              sendkey = "LEFTMETA+PAGEUP"; # Maximize window
    #            };
    #            down = {
    #              sendkey = "LEFTMETA+PAGEDOWN"; # Minimize window
    #            };
    #         };
    #     };
    #     tap = {
    #         "3" = {
    #            sendkey = "ALT+F2"; # Global search (KRunner)
    #          };
    #     };
    #   };
    # };
  };
}
