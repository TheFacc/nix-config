{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    # Closest upstream base for the Intel P16s family. As of this repo's
    # nixos-hardware input there is no lenovo-thinkpad-p16s-intel-gen4 module.
    (import "${inputs.hardware}/lenovo/thinkpad/p16s/intel")
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel

    # ThinkPad P16s Gen 4 model 21QV005WIX:
    # Intel Core Ultra 7 255H, Intel Arc Pro 140T, NVIDIA RTX PRO 500
    # Blackwell Generation Laptop GPU, Intel Wi-Fi 7 BE201.
    (import "${inputs.hardware}/common/gpu/nvidia/blackwell")
    (import "${inputs.hardware}/common/gpu/nvidia/prime.nix")
  ];

  # Keep filesystems, swap, initrd discovered modules, and bootloader details
  # in the installer-generated hardware-configuration.nix.

  # New Intel/NVIDIA hardware benefits from a recent kernel. This only takes
  # effect when the selected nixpkgs default kernel is older than 6.12.
  boot.kernelPackages =
    lib.mkIf (lib.versionOlder pkgs.linux.version "6.12") pkgs.linuxPackages_latest;

  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;

    # Let nixos-hardware keep using i915 by default. If the xe driver becomes
    # the better path for Arc Pro 140T on this machine, try:
    #   hardware.intelgpu.driver = "xe";
    intelgpu.vaapiDriver = lib.mkDefault "intel-media-driver";

    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };

    nvidia = {
      modesetting.enable = lib.mkDefault true;
      open = lib.mkDefault true;
      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.latest;

      powerManagement = {
        enable = lib.mkDefault true;
        finegrained = lib.mkDefault true;
      };

      prime = {
        offload = {
          enable = lib.mkOverride 990 true;
          enableOffloadCmd = lib.mkDefault true;
        };

        # Verify on bare metal after installation:
        #   lspci | grep -E "VGA|3D|Display"
        intelBusId = lib.mkDefault "PCI:0:2:0";
        nvidiaBusId = lib.mkDefault "PCI:1:0:0";
      };
    };

    trackpoint = {
      enable = lib.mkDefault true;
      emulateWheel = lib.mkDefault true;
    };
  };

  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  services = {
    thermald.enable = lib.mkDefault true;
    fprintd.enable = lib.mkDefault true;
  };

  # Fingerprint PAM lives in hosts/nixpad/default.nix. Enroll with:
  #   fprintd-enroll
}
