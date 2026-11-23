#############################################################
#
#  Nixex ~ Nix Plex - Home Theatre
#  NixOS on the ex-nixook laptop (i3 13th gen), headless:
#  Tailscale SSH, desktop on demand over RustDesk (see ./MIGRATION.md)
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

    ../common/optional/ui/xfce.nix # desktop on demand: systemctl start display-manager
    ../common/optional/services/rustdesk-host.nix # view that desktop over Tailscale
    ../common/optional/system/zram.nix
#    ../common/optional/serverr/rclone.nix
#     ../common/optional/system/pipewire.nix # audio
#     ../common/optional/kate.nix # kwrite is enough and default, right? write?
    # play
    ../common/optional/media/vlc.nix
    # ../common/optional/mpv.nix #--> home-manager
    # share
    ../common/optional/serverr/plex/server.nix
    ../common/optional/serverr/plex/tautulli.nix
    ../common/optional/serverr/jellyfin/jellyfin.nix
    ../common/optional/serverr/jellyfin/jellyfin-backup.nix
    # ../common/optional/serverr/jellyfin/jellyseerr.nix
  #  ../common/optional/serverr/rclone.nix
    ../common/optional/serverr/arr.nix
    ../common/optional/serverr/qbittorrent.nix
    ../common/optional/services/tailscale.nix
    ../common/optional/services/syncthing.nix # syncthing devices (JSON) + folders
#    ../common/optional/services/automount.nix
    ../common/optional/services/n8n.nix # n8n
    ../common/optional/services/vaultsync.nix # obsidian vault headless sync
    ../common/optional/services/vault-snapshot.nix # hourly vault history; Hermes can add named commits
    ../common/optional/services/hermes.nix # Hermes agent: vault assistant, Telegram + dashboard
    ../common/optional/services/telegram-bot-api.nix # local Bot API for Hermes (2 GB files)
    ../common/optional/notesmd.nix            # obsidian notes CLI editor
    ../common/optional/serverr/mediastorage.nix # mergerfs
    ../common/optional/serverr/tinymediamanager.nix # uses podman, waits for mergerfs
    ../common/optional/services/telegram-c2c.nix # Telegram C2C forwarding bot (+python3)
    ../common/optional/services/servermon.nix # Telegram alerts: disks, mounts, services, power, network
    ../common/optional/services/cloudflare-archive.nix # daily copy of Cloudflare request analytics (tvtime-archive)
    inputs.nur.modules.nixos.default
#    inputs.nur-xddxdd.nixosModules.flaresolverr#-21hsmw
#     inputs.nur.hmModules.nur

### temp while offline
    # ../common/optional/services/anydesk.nix

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

  services.xserver = {
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

  # No sleep, lid closed included (screen blanking is off in xfce.nix)
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  powerManagement.enable = false;
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
  };

  users.groups.media = {};

  services.jellyfin-backup.enable = true;
  services.vault-snapshot = {
    enable = true;
    offsite.enable = true; # needs the `vaulthistory` crypt remote in rclone.conf, see module
  };

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
