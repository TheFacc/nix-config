# { pkgs, lib, config, ... }:

{
  networking = {
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # If using dhcpcd:
    # dhcpcd.extraConfig = "nohook resolv.conf";
    # If using NetworkManager:
    networkmanager.dns = "none";
  };
  # Make sure you don't have services.resolved.enable on.
}