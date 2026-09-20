# Minimal NixOS VM for testing Niri + DMS before deploying to bare metal.
#
# Install workflow (recommended):
#   1. Create a Gen2 EFI VM (Hyper-V or VirtualBox), 4+ GB RAM, 40+ GB disk.
#   2. Install from the standard NixOS minimal ISO (graphical installer is fine).
#   3. Clone this repo, copy hardware-configuration.nix from the installer.
#   4. sudo nixos-rebuild switch --flake /path/to/nix-config#nixpad
#   5. Log in, run once: dms setup
#   6. Rebuild after config tweaks — no need for a custom ISO.
{ inputs, outputs, config, lib, ... }:
{
  imports = [
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Core ####################
    ../common/core
    ./hardware-configuration.nix

    #################### VM + desktop ####################
    ../common/optional/virtualisation/vm-guest.nix
    ../common/optional/system/pipewire.nix
    ../common/optional/system/zram.nix
    ../common/optional/ui/niri.nix
    ../common/optional/ui/dms.nix
    ../common/optional/ui/catppuccin.nix

    #################### Users ####################
    ../common/users/facc
  ];

  networking.hostName = "nixpad";

  # Pick one after you create the VM: "hyperv" or "virtualbox".
  local.vmGuest = "hyperv";

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };
  console.keyMap = "us-acentos";

  # Lean VM: skip printing, thermald, heavy services.
  system.stateVersion = "25.05";
}
