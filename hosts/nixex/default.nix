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
   # inputs.hardware.nixosModules.common-gpu-intel

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    # ../common/optional/services/openssh.nix # allow remote SSH access

    ../common/optional/plasma.nix # desktop environment
    ../common/optional/pipewire.nix # audio
    ../common/optional/kate.nix

    # play
    ../common/optional/vlc.nix
    # ../common/optional/mpv.nix #--> home-manager
    ../common/optional/serverr/plex/player.nix #TODO make declarative
    
    # share
    ../common/optional/serverr/plex/server.nix
    ../common/optional/serverr/plex/tautulli.nix
    ../common/optional/serverr/jellyfin/jellyfin.nix
    ../common/optional/serverr/jellyfin/jellyseerr.nix
    ../common/optional/serverr/rclone.nix
    ../common/optional/serverr/arr.nix
    ../common/optional/serverr/qbittorrent.nix
    ../common/optional/services/tailscale.nix
    inputs.nur.nixosModules.nur
#     inputs.nur.hmModules.nur

    #################### Users to Create ####################
    ../common/users/facc
    # ../common/users/campiglio
  ];
  plasma6.enable = true;

  # Enable Arr! #TODO make modular here maybe uhm
  # arrs.enable = true;

  # Enable some basic X server options
  services.xserver = {
    enable = true;
    xkb.layout = "it";
    xkb.variant = "";
  };
  # console.keymap = "it2";
#   services.xserver.displayManager = {
# #     # lightdm.enable = true;
# #     autoLogin.enable = true;
# #     autoLogin.user = "campiglio";
#     gdm.autoSuspend = false;
#   };

  networking = {
    hostName = "nixex";
    networkmanager.enable = true;
#     interfaces = { # ifconfig
#       wlp1s0 = {
#         ipv4.addresses = [{
#           address = "192.168.100.18";
#           prefixLength = 24;
#         }];
#       };
#     };
#     defaultGateway = "192.168.100.1";
    enableIPv6 = false;
  };

  # No sleep! -- not sure what is required here, but ALSO disable screen-off entirely from settings (#TODO declarative with plasma-manager)
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  powerManagement.enable = false;
  services.xserver.displayManager.gdm.autoSuspend = false;
  services.logind = {
    lidSwitch = "ignore";
    extraConfig = "IdleAction=ignore";
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
  system.stateVersion = "24.05";
}
