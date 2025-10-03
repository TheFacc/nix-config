{ config, ... }:
{
  programs.plasma.input.touchpads = [
      # /proc/bus/input/devices
      {
        enable = true;
        name = "VEN_04F3:00 04F3:32B1 Touchpad";
        naturalScroll = true;
        productId = "32b1";
        vendorId = "04f3";
      }
    ];
}
