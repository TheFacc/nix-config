# { allowed-unfree-packages, user, config, pkgs, options, lib, ... }:
{ inputs, outputs, lib, ... }:
# import needed user + all core modules + some optional modules
{
  imports = [
    # ./nixos-hardware/dell/g16/7630 # from nixos-hardware / lenovo legion 16IRX8H
    # ./hardware-configuration.nix # auto generated on installation
#     ./keyboard.nix # attempt to have rgb config heh

    #################### Hardware Modules ####################
    # inputs.hardware.nixosModules.common-cpu-intel
    # inputs.hardware.nixosModules.common-gpu-nvidia-prime
    # # inputs.hardware.nixosModules.common-pc-ssd
    # inputs.hardware.nixosModules.common-pc-laptop
    # inputs.hardware.nixosModules.common-pc-laptop-ssd
    # inputs.hardware.nixosModules.common-hidpi
    inputs.hardware.nixosModules.lenovo-legion-16irx8h

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    # ../common/optional/yubikey
    # ../common/optional/services/clamav.nix # depends on optional/msmtp.nix
    # ../common/optional/msmtp.nix # required for emailing clamav alerts
    # ../common/optional/services/openssh.nix
    ../common/optional/pipewire.nix # audio
    # ../common/optional/smbclient.nix # mount the ghost mediashare
    ../common/optional/vlc.nix # media player
    ../common/optional/audacity.nix # audio editor

    # Desktop
    ../common/optional/plasma.nix # desktop environment
    # ../common/optional/services/greetd.nix # display manager
    # ../common/optional/hyprland.nix # window manager
    ../common/optional/services/onedrive.nix # onedrive for linux
    ../common/optional/services/arr.nix # arr!



    # TODO Packages that should ideally be in /home instead of /hosts or stuff to fix idk
    ../common/optional/comms/telegram.nix
    ../common/optional/plex/player.nix
    # ../common/optional/plex/server.nix
    ../common/optional/opencv.nix
    ../common/optional/clangd.nix


    #################### Users to Create ####################
    ../common/users/facc 
  ];

  # By default, nixos-hardware uses nvidia in prime-offload mode.
  # This causes some issues with an external monitor that is directly connected to the gpu,
  # so we create a prime-sync specialization (more battery but ok at home)
  # (fyi seems to be broken with wayland currently, cant login)
  specialisation = {
    prime-sync.configuration = {
      system.nixos.tags = [ "prime-sync" ];
      hardware.nvidia = {
        prime.offload.enable = lib.mkForce false;
        prime.offload.enableOffloadCmd = lib.mkForce false;
        prime.sync.enable = lib.mkForce true;
      };
    };
    #TODO no-gpu.specialisation = ... # super battery mode? still i9 lol
  };
  plasma6.enable = true;
  arrs.enable = true; #TODO add other arrs with their enables, set default

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
    #plasma6
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  system.stateVersion = "23.11"; # Did you read the comment?

}
