#############################################################
#
#  Nixex ~ Nix Plex - Home Theatre
#  NixOS running on Toffa's Dell Inspiron
#
###############################################################

{ inputs, ... }: {
  imports = [
    #################### Hardware Modules ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    # ../common/optional/services/openssh.nix # allow remote SSH access

    ../common/optional/plasma.nix # desktop environment
    ../common/optional/pipewire.nix # audio
    # ../common/optional/smbclient.nix # mount the ghost mediashare
    ../common/optional/vlc.nix
    # ../common/optional/mpv.nix #--> home-manager

    #################### Users to Create ####################
    ../common/users/facc
    ../common/users/campiglio
  ];
  # Set plasma5 to stay stable
  plasma5.enable = true;

  # Enable some basic X server options
  services.xserver.enable = true;
  services.xserver.displayManager = {
    lightdm.enable = true;
    autoLogin.enable = true;
    autoLogin.user = "campiglio";
  };

  networking = {
    hostName = "nixex";
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}