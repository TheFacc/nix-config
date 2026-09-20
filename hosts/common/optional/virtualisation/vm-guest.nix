# VM guest integrations. Enable exactly one backend on the host.
{ config, lib, ... }:
{
  options.local.vmGuest = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "hyperv" "virtualbox" ]);
    default = null;
    description = "Hypervisor guest additions to enable for this host.";
  };

  config = lib.mkMerge [
    (lib.mkIf (config.local.vmGuest == "hyperv") {
      virtualisation.hypervGuest.enable = true;
    })
    (lib.mkIf (config.local.vmGuest == "virtualbox") {
      virtualisation.virtualbox.guest.enable = true;
    })
  ];
}
