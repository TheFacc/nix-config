# { allowed-unfree-packages, user, config, pkgs, options, lib, ... }:
{ inputs, outputs, config, lib, ... }:
# import needed user + all core modules + some optional modules
{
  imports = [

    #################### Hardware Modules ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    ../common/optional/pipewire.nix # audio
    ../common/optional/bluetooth.nix
    ../common/optional/ios.nix # ios file transfer support
    ../common/optional/zram.nix # zram swap

    # Desktop
    ../common/optional/plasma.nix # desktop environment

    # Services
    # ../common/optional/services/onedrive.nix # onedrive for linux
    ../common/optional/services/tailscale.nix # tailscale vpn
    ../common/optional/services/syncthing-devices.nix # syncthing devices IDs
    ../common/optional/services/syncthing-folders.nix # syncthing sync folders

    # Comms
    ../common/optional/comms/telegram.nix

    # Media
    ../common/optional/vlc.nix # media player (mpv is in home config)
    ../common/optional/serverr/plex/player.nix # plex media player
    ../common/optional/serverr/jellyfin/jellyfin-mpv.nix # jellyfin media player

    # Notes
    ../common/optional/obsidian.nix # obsidian.md

    # Dev
#     ../common/optional/clangd.nix
    ../common/optional/nixd.nix

    # Tools
    ../common/optional/rar.nix # RAR archives

    # Web
    ../common/optional/dbeaver.nix # MySQL database manager

    #################### Users to Create ####################
    ../common/users/facc 
  ];
  plasma6.enable = true;

  networking.hostName = "nixook";

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };

  # nixpkgs.overlays = [ # TODO use this overlay instead of vscode.nix - inputs.
  #   inputs.nix-vscode-extensions.overlays.default
  # ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "it";
    xkb.variant = "";
  };

  # Configure console keymap
  console.keyMap = "it2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Cooling management
  services.thermald.enable = lib.mkDefault true;

  system.stateVersion = "24.11"; # Did you read the comment?

}
