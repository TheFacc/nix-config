# { allowed-unfree-packages, user, config, pkgs, options, lib, ... }:
{ inputs, outputs, config, lib, ... }:
# import needed user + all core modules + some optional modules
{
  imports = [
    # ./nixos-hardware/dell/g16/7630 # from nixos-hardware / lenovo legion 16IRX8H
    # ./hardware-configuration.nix # auto generated on installation
#     ./keyboard.nix # attempt to have rgb config heh

    #################### Hardware Modules ####################
    inputs.hardware.nixosModules.common-cpu-intel
    # inputs.hardware.nixosModules.common-gpu-nvidia#-prime ?? not found # 2024-05-26 manually added below so i can specify version 555
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    inputs.hardware.nixosModules.common-hidpi
    # inputs.hardware.nixosModules.lenovo-legion-16irx8h

    #################### Required Configs ####################
    ../common/core
    ./hardware-configuration.nix

    #################### Host-specific Optional Configs ####################
    # ../common/optional/yubikey
    # ../common/optional/services/clamav.nix # depends on optional/msmtp.nix
    # ../common/optional/msmtp.nix # required for emailing clamav alerts
    # ../common/optional/services/openssh.nix
    ../common/optional/pipewire.nix # audio
    ../common/optional/bluetooth.nix
    # ../common/optional/smbclient.nix # mount the ghost mediashare
    ../common/optional/vlc.nix # media player
    ../common/optional/audacity.nix # audio editor

    # Desktop
    ../common/optional/plasma.nix # desktop environment
    # ../common/optional/services/greetd.nix # display manager
    # ../common/optional/hyprland.nix # window manager
    ../common/optional/services/onedrive.nix # onedrive for linux
    ../common/optional/services/tailscale.nix # tailscale vpn
    ../common/optional/virtualbox.nix # virtualbox
    ../common/optional/zotero.nix # zotero
    # ../common/optional/kdiskmark.nix # disk benchmark

    # TODO Packages that should ideally be in /home instead of /hosts or stuff to fix idk
    ../common/optional/comms/telegram.nix
    ../common/optional/plex/player.nix
    ../common/optional/clangd.nix

    ../common/optional/ios.nix

    #################### Users to Create ####################
    ../common/users/facc 
  ];

  # By default, nixos-hardware uses nvidia in prime-offload mode.
  # This causes some issues with an external monitor that is directly connected to the gpu,
  # so we create a prime-sync specialization (more battery but ok at home)
  # (fyi seems to be broken with wayland currently, cant login)
  specialisation = {
    nvidiaBeta.configuration = { #TODO not sure this works like this
      system.nixos.tags = [ "nvidia-beta" ];
      environment.etc."specialisation".text = "nvidiaBeta";
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    };
    prime-sync.configuration = {
      system.nixos.tags = [ "prime-sync" ];
      environment.etc."specialisation".text = "prime-sync";
      hardware.nvidia = {
        prime.offload.enable = lib.mkForce false;
        prime.offload.enableOffloadCmd = lib.mkForce false;
        prime.sync.enable = lib.mkForce true;
      };
    };
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
  plasma6.enable = true;

  networking.hostName = "nixossone";

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };
  # nixpkgs.overlays = [
  #   (
  #     final: prev: {
  #       # Your own overlays...
  #     }
  #   )
  # ] ++ flake-overlays;


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # Configure keymap in X11
  services.xserver = {
    # plasma5
    #layout = "us";
    #xkbVariant = "intl";
    # plasma6
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # # from nixos-hardware lenovo-legion-16irx8h
  # hardware.opengl.extraPackages = with pkgs; [
  #   vaapiVdpau
  # ];
  services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];
  boot.initrd.kernelModules = ["nvidia"];
  boot.extraModulePackages = [
    # config.boot.kernelPackages.lenovo-legion-module
    config.boot.kernelPackages.nvidia_x11
    # config.boot.kernelPackages.nvidia_wayland # heh magari
  ];
  hardware = {
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.stable; # forcing beta to have 555 as of 2024-05-25 (maybe not rly forcing tho lol)
      # package = config.boot.kernelPackages.nvidiaPackages.mkDriver { # https://www.reddit.com/r/NixOS/comments/1cx9wsy/comment/l51ubth/
      #   version = "555.42.02";
      #   sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
      #   sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #   openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #   settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA="; 
      #   persistencedSha256 = lib.fakeSha256;
      # };
      modesetting.enable = lib.mkDefault true;
      powerManagement.enable = lib.mkDefault true;
      prime = {
        offload = {
          enable = lib.mkOverride 990 true;
          enableOffloadCmd = lib.mkIf config.hardware.nvidia.prime.offload.enable true; # Provides `nvidia-offload` command.
        };
        # intelBusId = "PCI:00:02:0";
        # nvidiaBusId = "PCI:01:00:0";
        # https://discourse.nixos.org/t/struggling-with-nvidia-prime/13794
        intelBusId = "0@0:2:0";
        nvidiaBusId = "1@0:0:0";
      };
    };
  };
  boot.kernelParams = [ "nvidia-drm.modeset=1" ]; # idk if needed
  # # Cooling management
  services.thermald.enable = lib.mkDefault true;
  services.xserver.dpi = 189; # √(2560² + 1600²) px / 16 in ≃ 189 dpi

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users."${user}" = {
  #   isNormalUser = true;
  #   description = user;
  #   extraGroups = [ "networkmanager" "wheel" ];
  #   packages = with pkgs; [
  #     firefox
  #   ];
  # };
  # nix.settings.experimental-features = ["nix-command" "flakes"];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users."${user}" = {
  #   extraGroups = [ "input" ];
  #   packages = with pkgs; [
  #     # acpilight
  #     # brightnessctl
  #   ];
  # };

#   #hardware.system76.enableAll = true;
#   boot.kernelModules = [ "i2c-dev" "i2c-piix4" ];
#   services.hardware.openrgb.enable = true;
#   services.udev.extraRules = ''
#   SUBSYSTEMS=="usb|hidraw", ATTRS{idVendor}=="187c", ATTRS{idProduct}=="0551", TAG+="uaccess", TAG+="Dell_G_Series_LED_Controller"
#   '';

  system.stateVersion = "23.11"; # Did you read the comment?

}
