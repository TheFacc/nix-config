#############################################################
#
#  Nixex ~ Nix Plex - Home Theatre
#  NixOS running on Toffa's Dell Inspiron
#
###############################################################

{ inputs, lib, outputs, ... }: {
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
    # play
    ../common/optional/vlc.nix
    # ../common/optional/mpv.nix #--> home-manager
    # ../common/optional/plex/player.nix #TODO
    # share
    ../common/optional/plex/server.nix
    # ../common/optional/plex/tautulli.nix #TODO
    ../common/optional/services/rclone.nix
    ../common/optional/services/arr.nix
    # ../common/optional/services/transmission.nix # jee its terrible
    ../common/optional/services/qbittorrent.nix

    #################### Users to Create ####################
    ../common/users/facc
    ../common/users/campiglio
  ];
  # Set plasma5 to stay stable
  plasma5.enable = true;

  # Enable Arr!
  # arrs.enable = true;

  # Enable some basic X server options
  services.xserver = {
    enable = true;
    displayManager = {
      # lightdm.enable = true;
      autoLogin.enable = true;
      autoLogin.user = "campiglio";
    };
    xkb.layout = "it";
    xkb.variant = "";
  };
  # console.keymap = "it2";

  networking = {
    hostName = "nixex";
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  users.groups.media = {};

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };


  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
