# { allowed-unfree-packages, user, config, pkgs, options, lib, ... }:
{ inputs, outputs, config, lib, pkgs, ... }:
# import needed user + all core modules + some optional modules
{
  imports = [
    #################### Hardware Modules ####################
    # ./nixos-hardware/dell/g16/7630 # from nixos-hardware / not available, similar is Lenovo Legion 16IRX8H
    inputs.hardware.nixosModules.common-cpu-intel
    # inputs.hardware.nixosModules.common-gpu-nvidia#-prime ?? not found # 2024-05-26 manually added below so i can specify version 555
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    inputs.hardware.nixosModules.common-hidpi
    # inputs.hardware.nixosModules.lenovo-legion-16irx8h
#     ./keyboard.nix # attempt to have rgb config heh

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix
    ./nvidia.nix

    #################### Host-specific Optional Configs ####################
    ../common/optional/system/pipewire.nix # audio
    ../common/optional/system/bluetooth.nix
    ../common/optional/system/ios.nix # ios file transfer support
    ../common/optional/system/zram.nix # zram swap

    # Desktop
     ../common/optional/ui/plasma.nix # desktop environment -- enable from homemanager TEST
     ../common/optional/ui/catppuccin.nix # theme

    # Services
    # ../common/optional/services/onedrive.nix # onedrive for linux
    ../common/optional/services/tailscale.nix # tailscale vpn
    ../common/optional/services/syncthing-devices.nix # syncthing devices IDs
    ../common/optional/services/syncthing-folders.nix # syncthing sync folders
    ../common/optional/docker.nix # sorry nix
    ../common/optional/virtualbox.nix # virtualbox
    # ../common/optional/services/automount.nix # automatically mount external disks

    # Comms
    ../common/optional/comms/telegram.nix
    ../common/optional/comms/beeper.nix

    # Media
    ../common/optional/media/vlc.nix # media player (mpv is in home config)
    # ../common/optional/serverr/plex/player.nix # plex media player
    ../common/optional/serverr/jellyfin/jellyfin-mpv.nix # jellyfin media player
    ../common/optional/media/steam.nix # steam

    # Notes
#     ../common/optional/zotero.nix # zotero
    ../common/optional/obsidian.nix # obsidian.md

    # Dev
    # ../common/optional/dev/clangd.nix
    ../common/optional/dev/nixd.nix
    ../common/optional/dev/webdev.nix # node php jq chrome
    ../common/optional/dev/cursor.nix # cursor

    # Tools
    ../common/optional/rar.nix # RAR archives
    ../common/optional/anydesk.nix # remote desktop

    # Web
    ../common/optional/media/persepolis.nix # download manager (~IDM)
    ../common/optional/dev/dbeaver.nix # MySQL database manager

    #################### Users to Create ####################
    ../common/users/facc 
  ];

  networking.hostName = "nixossone";

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };
  # nixpkgs.overlays = [
  #   (
  #     final: prev: {
  #       # Your own overlays...
  #     }
  #   )
  # ] ++ flake-overlays;


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # Configure keymap in X11
  services.xserver = {
    # plasma5
    #layout = "us";
    #xkbVariant = "intl";
    # plasma6
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # # Cooling management
  services.thermald.enable = lib.mkDefault true;
  services.xserver.dpi = 189; # √(2560² + 1600²) px / 16 in ≃ 189 dpi

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users."${user}" = {
  #   isNormalUser = true;
  #   description = user;
  #   extraGroups = [ "networkmanager" "wheel" ];
  #   packages = with pkgs; [
  #     firefox
  #   ];
  # };
  # nix.settings.experimental-features = ["nix-command" "flakes"];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users."${user}" = {
  #   extraGroups = [ "input" ];
  #   packages = with pkgs; [
  #     # acpilight
  #     # brightnessctl
  #   ];
  # };

#   #hardware.system76.enableAll = true;
#   boot.kernelModules = [ "i2c-dev" "i2c-piix4" ];
#   services.hardware.openrgb.enable = true;
#   services.udev.extraRules = ''
#   SUBSYSTEMS=="usb|hidraw", ATTRS{idVendor}=="187c", ATTRS{idProduct}=="0551", TAG+="uaccess", TAG+="Dell_G_Series_LED_Controller"
#   '';

  system.stateVersion = "25.05"; # Did you read the comment?

}
