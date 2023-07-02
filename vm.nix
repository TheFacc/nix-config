#{ config, pkgs, ... }: 
#let
#  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
#in {
#  users.users.facc.packages = with pkgs; [
 #   unstable.vmware-workstation # https://discourse.nixos.org/t/installing-only-a-single-package-from-unstable/5598 
#  ];
#}
{ config, lib, pkgs, ... }: 
{ # https://github.com/NixOS/nixops/issues/370#issuecomment-162787764
#  users.users.facc.packages = with pkgs; [ virtualbox ]; # this installs for user but is messed up
  virtualisation.virtualbox.host.enable = true; # this will automatically install vbox correctly
#  virtualisation.virtualbox.guest.enable = true; # vbox Guest Additions (eg to share folders)
  users.extraGroups.vboxusers.members = [ "facc" ];
}
