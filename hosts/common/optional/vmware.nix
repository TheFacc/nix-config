{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.vmware-workstation
  ];
}
