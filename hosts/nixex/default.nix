#############################################################
#
#  Nixex ~ Nix Plex - Home Theatre
#  NixOS running on my old Samsung tank
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

    ../common/optional/ui/plasma.nix # desktop environment
    ../common/optional/system/zram.nix
#    ../common/optional/serverr/rclone.nix
#     ../common/optional/system/pipewire.nix # audio
#     ../common/optional/kate.nix # kwrite is enough and default, right? write?
    # play
    ../common/optional/media/vlc.nix
    # ../common/optional/mpv.nix #--> home-manager
#    ../common/optional/plex/player.nix #TODO make declarative... niente han fatto in tempo a montarsi la testa, ciao
    # share
    ../common/optional/serverr/plex/server.nix
    ../common/optional/serverr/plex/tautulli.nix
    ../common/optional/serverr/jellyfin/jellyfin.nix #TODO config
    ../common/optional/serverr/jellyfin/jellyseerr.nix
  #  ../common/optional/serverr/rclone.nix
    ../common/optional/serverr/arr.nix
    ../common/optional/serverr/qbittorrent.nix
    ../common/optional/services/tailscale.nix
    ../common/optional/services/syncthing.nix # syncthing devices (JSON) + folders
#    ../common/optional/services/automount.nix
    ../common/optional/services/n8n.nix # n8n
    ../common/optional/services/vaultsync.nix # obsidian vault headless sync
    ../common/optional/notesmd.nix            # obsidian notes CLI editor
    ../common/optional/serverr/mediastorage.nix # mergerfs
    ../common/optional/serverr/tinymediamanager.nix # uses podman, waits for mergerfs
    ../common/optional/services/telegram-c2c.nix # Telegram C2C forwarding bot (+python3)
    inputs.nur.modules.nixos.default
#    inputs.nur-xddxdd.nixosModules.flaresolverr#-21hsmw
#     inputs.nur.hmModules.nur

### temp while offline
    # ../common/optional/anydesk.nix

    # copyparty NixOS module
#    inputs.copyparty.nixosModules.default
#    ../common/optional/services/copyparty.nix

    #################### Users to Create ####################
    ../common/users/facc
 #   ../common/users/campiglio
  ];

  # Enable Arr! #TODO make modular here maybe uhm
  # arrs.enable = true;
#   boot.supportedFilesystems = ["ntfs"];

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
    enableIPv6 = true;
  };

  # No sleep! -- not sure what is required here, but ALSO disable screen-off entirely from settings (#TODO declarative with plasma-manager)
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  powerManagement.enable = false;
  services.displayManager.gdm.autoSuspend = false;
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
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
    permittedInsecurePackages = outputs.allowed-insecure-packages;
  };


  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
