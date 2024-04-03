# main config for facc on g16
# references all core stuff and most optional stuff

{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    #################### Required Configs ####################
    common/core #required

    #################### Host-specific Optional Configs ####################
    # common/optional/sops.nix
    # common/optional/helper-scripts

    # common/optional/desktops/gtk.nix

    # Browsers
    common/optional/browsers/firefox.nix
    common/optional/browsers/brave.nix

    # Dev
    common/optional/dev/vscode.nix
    common/optional/dev/matlab.nix 

    # Comms
    # common/optional/comms/telegram.nix

    # Services
    common/optional/services/onedrive.nix 
    common/optional/services/arr.nix 

    # common/optional/games/steam.nix
  ];

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };
}