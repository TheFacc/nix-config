# nixex on the ex-nixook laptop (Intel i3 13th gen, NVMe): TEMPLATE until install day.
# On install day, replace every REPLACE-ME value and the kernel module lists with the
# output of `nixos-generate-config --root /mnt` (see ./MIGRATION.md). Keep the btrfs
# subvolume options and the /mnt/ssd512 mount; LUKS unlock options live in ./default.nix.
#
# Layout: GPT, ESP (vfat, /boot) + LUKS2 "cryptroot" -> btrfs with @ @home @nix @log. No disk swap (zram).
{ config, lib, modulesPath, ... }:
let
  btrfsOpts = subvol: [ "subvol=${subvol}" "compress=zstd" "noatime" ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_usb_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/REPLACE-ME-LUKS-PARTITION-UUID";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = btrfsOpts "@";
  };
  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = btrfsOpts "@home";
  };
  fileSystems."/nix" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = btrfsOpts "@nix";
  };
  fileSystems."/var/log" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = btrfsOpts "@log";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-ME-ESP-UUID";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Moved over from the old nixex (same disk, same UUID)
  fileSystems."/mnt/ssd512" = {
    device = "/dev/disk/by-uuid/c8b71c18-9ce1-4b44-b3bc-2a9d97131045";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
