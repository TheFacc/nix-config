{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:3" "noatime" "ssd" "discard=async" ];
    };

  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/ffb58d80-33bf-46a1-bab9-9c5f097fe7e5";
    allowDiscards = true;
  };

  fileSystems."/home" =
    { device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:3" "noatime" "ssd" "discard=async" ];
    };

  fileSystems."/nix" =
    { device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:3" "noatime" "ssd" "discard=async" ];
    };

  fileSystems."/.snapshots" =
    { device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:3" "noatime" "ssd" "discard=async" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/2CD4-BD1E";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/efi" =
    { device = "/dev/disk/by-uuid/A23A-6D52";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.npu.enable = true; ## doesnt exist hmmm - ok flake update fixed
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
