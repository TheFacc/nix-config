# OpenLogi — local-first Logitech Options+ alternative.
# Installs the GUI/CLI, udev rules (hidraw / uinput / event nodes), and starts
# openlogi-agent with the graphical session.
#
# Device remaps, DPI, SmartShift, and per-app overlays live in
# ~/.config/openlogi/config.toml after first run (keys are hardware-generated).
# Do not manage that file from Nix until those keys exist, or Home Manager will
# fight the GUI.
{ inputs, ... }:
{
  imports = [ inputs.openlogi.nixosModules.default ];

  programs.openlogi = {
    enable = true;
    launchAtLogin = true;
  };

  # OpenLogi's packaged rules only TAG+="uaccess". logind applies that ACL when
  # a device appears, not when `udevadm trigger` runs after nixos-rebuild, so a
  # Bluetooth mouse that was already connected stays /dev/hidraw* 0600 and
  # OpenLogi dies with HID PermissionDenied (os error 13). MODE/GROUP are
  # applied on trigger, so rebuild actually opens the node.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", MODE="0660", GROUP="users"
    SUBSYSTEM=="hidraw", KERNELS=="*:046D:*", MODE="0660", GROUP="users"
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ATTRS{idVendor}=="046d", MODE="0660", GROUP="users"
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", KERNELS=="*:046D:*", MODE="0660", GROUP="users"
  '';
}
