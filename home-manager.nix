{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-22.11.tar.gz";
in
{
  # IMPORT
  # The following import will introduce a new NixOS option called home-manager.users
  # whose type is an attribute set that maps user names to Home Manager configurations.
  imports = [ (import "${home-manager}/nixos") ];

  # CONFIG
  users.users.facc.extraGroups = [ "input" ];
  home-manager.users.facc = {
    /* The home.stateVersion option does not have a default and must be set */
    home.stateVersion = "22.11";

    # - Git stuff
    programs.git = {
      enable = true;
      userName  = "TheFacc";
      userEmail = "imthefacc@gmail.com";
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
    home.packages = with pkgs; [
      libinput
      fusuma
      xdotool
    ];
    services.fusuma = {
      enable = true;
      #extraPackages = with pkgs; [ xdotool ];
      settings = {
        swipe = {
            "3" = {
               left = {
                 sendkey = "LEFTALT+RIGHT"; # History forward
               };
               right = {
                 sendkey = "LEFTALT+LEFT"; # History back
               };
               up = {
                 sendkey = "LEFTMETA+PAGEUP"; # Maximize window
               };
               down = {
                 sendkey = "LEFTMETA+PAGEDOWN"; # Minimize window
               };
            };
        };
        tap = {
            "3" = {
               sendkey = "ALT+F2"; # Global search (KRunner)
             };
        };
      };
    };
  };
}
