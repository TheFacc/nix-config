# { allowed-unfree-packages, user, config, pkgs, options, lib, ... }:
{ inputs, outputs, config, lib, pkgs, ... }:
# import needed user + all core modules + some optional modules
{
  # By default, nixos-hardware uses nvidia in prime-offload mode.
  # This causes some issues with an external monitor that is directly connected to the gpu,
  # so we create a prime-sync specialization (more battery but ok at home)
  # (fyi seems to be broken with wayland currently, cant login)
  specialisation = {
    # nvidiaBeta.configuration = { #TODO not sure this works like this
    #   system.nixos.tags = [ "nvidia-beta" ];
    #   environment.etc."specialisation".text = "nvidiaBeta";
    #   hardware.nvidia = {
    #     package = config.boot.kernelPackages.nvidiaPackages.beta;
    #   };
    # };
    # prime-sync.configuration = {
    #   system.nixos.tags = [ "prime-sync" ];
    #   environment.etc."specialisation".text = "prime-sync";
    #   hardware.nvidia = {
    #     prime.offload.enable = lib.mkForce false;
    #     prime.offload.enableOffloadCmd = lib.mkForce false;
    #     prime.sync.enable = lib.mkForce true;
    #   };
    # };
    # reverse-sync.configuration = {
    #   system.nixos.tags = [ "reverse-sync" ];
    #   environment.etc."specialisation".text = "reverse-sync";
    #   hardware.nvidia = {
    #     prime.offload.enable = lib.mkForce false;
    #     prime.offload.enableOffloadCmd = lib.mkForce false;
    #     prime.reverseSync.enable = lib.mkForce true;
    #   };
    # };

    #TODO no-gpu.specialisation = ... # super battery mode? still i9 lol (no external screen!)
    # no-nvidia.configuration = {
    #   system.nixos.tags = [ "no-nvidia" ];
    #   hardware.nvidia = {
    #     prime.offload.enable = lib.mkForce false;
    #     prime.offload.enableOffloadCmd = lib.mkForce false;
    #     prime.sync.enable = lib.mkForce false;
    #     prime.reverseSync.enable = lib.mkForce false;
    #   };
    #   # https://nixos.wiki/wiki/Nvidia#Disable_Nvidia_dGPU_completely
    #   boot.extraModprobeConfig = ''
    #     blacklist nouveau
    #     options nouveau modeset=0
    #   '';
    #   services.udev.extraRules = ''
    #     # Remove NVIDIA USB xHCI Host Controller devices, if present
    #     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
    #     # Remove NVIDIA USB Type-C UCSI devices, if present
    #     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
    #     # Remove NVIDIA Audio devices, if present
    #     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
    #     # Remove NVIDIA VGA/3D controller devices
    #     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
    #   '';
    #   boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];
    # };

  };

    ### <nvidia> ###
  # # from nixos-hardware lenovo-legion-16irx8h
  # hardware.opengl.extraPackages = with pkgs; [
  #   vaapiVdpau
  # ];
  services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];
  boot.initrd.kernelModules = ["nvidia"];
  # boot.extraModulePackages = [
  #   # config.boot.kernelPackages.lenovo-legion-module
  #   config.boot.kernelPackages.nvidia_x11 ##### random KERNEL PANIC on 550.142-6.12.13 and also 565.77
  #   # config.boot.kernelPackages.nvidia_wayland # heh magari
  # ];
  hardware = {
    nvidia = {
      open = true; # https://github.com/NixOS/nixpkgs/commit/43764ae2c337f5e5f6b5485a7092734f3b1fdf2d
      package = config.boot.kernelPackages.nvidiaPackages.latest; # beta > latest > production = stable
      # package = config.boot.kernelPackages.nvidiaPackages.mkDriver { # https://www.reddit.com/r/NixOS/comments/1cx9wsy/comment/l51ubth/
      #   version = "555.42.02";
      #   sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
      #   sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #   openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #   settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #   persistencedSha256 = lib.fakeSha256;
      # };
      modesetting.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        # finegrained = true; # low power: https://download.nvidia.com/XFree86/Linux-x86_64/460.73.01/README/dynamicpowermanagement.html
      };
      prime = {
        offload = {
          enable = lib.mkOverride 990 true;
          enableOffloadCmd = lib.mkIf config.hardware.nvidia.prime.offload.enable true; # Provides `nvidia-offload` command.
        };
        intelBusId = "PCI:00:02:0";
        nvidiaBusId = "PCI:01:00:0";
        # https://discourse.nixos.org/t/struggling-with-nvidia-prime/13794
#         intelBusId = "0@0:2:0"; # format not accepted anymore since apr2025
#         nvidiaBusId = "1@0:0:0";
      };
    };
  };
  boot.kernelParams = [ "nvidia-drm.modeset=1" ]; # idk if needed
  ### </nvidia> ###
}
