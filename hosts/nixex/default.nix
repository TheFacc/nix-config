#############################################################
#
#  Nixex ~ Nix Plex - Home Theatre
#  NixOS on the ex-nixook laptop (i3 13th gen), headless:
#  Tailscale SSH, desktop on demand over RustDesk (see ./MIGRATION.md)
#
###############################################################

{ inputs, lib, outputs, pkgs, ... }: {
  imports = [
    #################### Hardware Modules ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.lanzaboote.nixosModules.lanzaboote # Secure Boot
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

  # ssd512 is nofail (USB enclosure), so nothing orders services after it: wait for it,
  # or qBittorrent writes its downloads into the empty mountpoint on the root disk.
  # After a USB dropout the services stop with the mount; plugging it back in mounts it
  # and starts them again (same as the media pool in mediastorage.nix).
  systemd.services.qBittorrent = {
    unitConfig.RequiresMountsFor = [ "/mnt/ssd512" ];
    wantedBy = [ "mnt-ssd512.mount" ];
  };
  systemd.services.podman-tinyMediaManager.wantedBy = [ "mnt-ssd512.mount" ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="c8b71c18-9ce1-4b44-b3bc-2a9d97131045", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-ssd512.mount"
  '';

  # IDs as allocated on the old nixex: rsync'd /var/lib, the vault ACLs and the media disks
  # (facc:media) keep their owners. Users/groups not listed here are already static upstream.
  users.users = lib.mapAttrs (_: uid: { inherit uid; }) {
    cloudflare-archive = 983;
    vault-history-web = 984;
    hermes = 985;
    servermon = 986;
    vaultsync = 987;
    n8n = 988;
    prowlarr = 993;
    jellyfin = 994;
  };
  users.groups = lib.mapAttrs (_: gid: { inherit gid; }) {
    cloudflare-archive = 981;
    vault-history = 982;
    hermes = 983;
    servermon = 984;
    vault = 985;
    n8n = 986;
    media = 993;
  };

  services.jellyfin-backup.enable = true;
  services.vault-snapshot = {
    enable = true;
    offsite.enable = true; # needs the `vaulthistory` crypt remote in rclone.conf, see module
  };

  # Unattended reboot: the TPM releases the LUKS key only if PCR 7 (Secure Boot state
  # and keys) matches, so it needs lanzaboote's signed boot chain. The passphrase stays
  # as fallback. Enrollment and recovery: ./MIGRATION.md
  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce false; # lanzaboote replaces it
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl"; # on @: never wipe it, the firmware trusts these keys
      # First boot makes the keys, re-signs and reboots; systemd-boot then enrolls
      # them (firmware in Setup Mode), Microsoft keys included for option ROMs
      autoGenerateKeys.enable = true;
      autoEnrollKeys = {
        enable = true;
        autoReboot = true;
      };
    };
    initrd.luks.devices."cryptroot" = {
      crypttabExtraOpts = [ "tpm2-device=auto" ];
      allowDiscards = true; # TRIM through LUKS for the NVMe
    };
  };
  environment.systemPackages = [ pkgs.sbctl ];

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
    permittedInsecurePackages = outputs.allowed-insecure-packages;
  };


  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
