# ThinkPad P16s Gen 4 — bare metal, dual boot with Windows 11, sadly.
#
# Disk layout (single NVMe, GPT, UEFI, Secure Boot disabled):
#   nvme0n1p1  260 MB   ESP        shared with Windows — NEVER reformat, mounted /efi
#   nvme0n1p2   16 MB   MSR        Windows
#   nvme0n1p3  ~450 GB  NTFS       Windows C:
#   nvme0n1p5    1 GB   XBOOTLDR   FAT32, NixOS kernels + initrds, mounted /boot
#   nvme0n1p6  ~500 GB  LUKS2      -> btrfs: @ @home @nix @snapshots, compress=zstd
#   nvme0n1p4  1.95 GB  WinRE      Windows recovery
#
# Install workflow (bare metal):
#   1. Boot the GRAPHICAL NixOS ISO (Secure Boot disabled in firmware).
#   2. Shrink Windows with GParted, create the NixOS partition.
#   3. XBOOTLDR + LUKS + btrfs subvolumes by hand, mount under /mnt.
#   4. nixos-generate-config --root /mnt  -> copy into hosts/nixpad/
#   5. nixos-install --flake /mnt/etc/nixos/nix-config#nixpad
#   See ~/docs/nixos-install-runbook.md for the full step-by-step runbook.
{ inputs, outputs, config, lib, ... }:
{
  imports = [
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    ./hardware-config-p16s-gen4.nix

    #################### Core ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    ../common/optional/system/pipewire.nix
    ../common/optional/system/bluetooth.nix
    ../common/optional/system/ios.nix
    ../common/optional/system/zram.nix

    # Desktop
    ../common/optional/ui/niri.nix
    ../common/optional/ui/dms.nix
    ../common/optional/ui/catppuccin.nix

    # Services
    # ../common/optional/services/onedrive.nix
    ../common/optional/services/tailscale.nix
    # ../common/optional/services/syncthing.nix
    ../common/optional/docker.nix
    # ../common/optional/virtualbox.nix
    # ../common/optional/services/automount.nix

    # Comms
    ../common/optional/comms/telegram.nix
    ../common/optional/comms/beeper.nix

    # Media
    ../common/optional/media/vlc.nix
    ../common/optional/serverr/jellyfin/jellyfin-mpv.nix
    ../common/optional/media/steam.nix

    # Notes
    ../common/optional/obsidian.nix

    # Dev
    ../common/optional/dev/nixd.nix
    # ../common/optional/dev/webdev.nix
    ../common/optional/dev/cursor.nix
    ../common/optional/dev/coding-agents.nix # claude, codex

    # Tools
    ../common/optional/appimage.nix
    ../common/optional/openlogi.nix # Logitech Options+ alternative
    ../common/optional/rar.nix

    #################### Users ####################
    ../common/users/facc
  ];

  networking.hostName = "nixpad";
  networking.networkmanager.enable = true;

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };

  #################### Boot ####################
  # UEFI + systemd-boot in a split ESP / XBOOTLDR layout.
  #
  # The Windows ESP (nvme0n1p1) is only 260 MB with ~218 MB free, and one NixOS
  # generation costs roughly 60-120 MB (kernel + systemd initrd). Three
  # generations do not fit there. So the ESP holds only systemd-bootx64.efi
  # (~100 KB) and is mounted at /efi, while kernels and initrds live on a
  # dedicated 1 GB XBOOTLDR partition (nvme0n1p5, FAT32, GPT type GUID
  # bc13c2ff-59e6-4262-a352-b275fd6f7172) mounted at /boot.
  #
  # This keeps the single unified boot menu: systemd-boot itself still lives on
  # the Windows ESP and still auto-detects EFI/Microsoft/Boot/bootmgfw.efi
  # there, so Windows appears in the menu with no chainload config.
  #
  # FALLBACK if the XBOOTLDR partition was never created: set
  #   efiSysMountPoint = "/boot";  drop xbootldrMountPoint;  configurationLimit = 2;
  # and mount nvme0n1p1 at /boot instead of /efi. Then watch `df -h /boot`.
  boot.loader.systemd-boot = {
    enable = true;
    xbootldrMountPoint = "/boot";
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  # systemd in initrd: caches the LUKS passphrase and retries it on every
  # encrypted device, so growing the btrfs pool later with
  # `btrfs device add` still means typing the passphrase only once.
  boot.initrd.systemd.enable = true;

  # Mount the Windows NTFS partition. Works read-write because C: is decrypted
  # and Fast Startup is disabled on the Windows side — if Windows ever
  # re-enables Fast Startup or hibernates, ntfs3 will refuse or mount
  # read-only. That is the safety net working, not a fault.
  boot.supportedFilesystems = [ "ntfs" ];

  services.fstrim.enable = true;

  # Get battery info (was enabled by Plasma automatically, now we need it explicitly)
  services.upower.enable = true;

  #################### Desktop bits ####################
  # Makes Dolphin friendlier outside Plasma: trash, removable devices, and
  # common gvfs-backed locations work through the usual desktop services.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  services.xserver.xkb = {
    layout = "it";
  };
  console.useXkbConfig = true;

  # fprintd is already enabled in hardware-config-p16s-gen4.nix.
  # Enroll after rebuild: fprintd-enroll
  # Then swipe at tuigreet / lock / sudo; password still works as fallback.
  security.pam.services = {
    login.fprintAuth = true;
    greetd.fprintAuth = true;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  system.stateVersion = "25.05";
}
