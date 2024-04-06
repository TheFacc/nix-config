#
# Basic user for viewing media on nixex
#

{ pkgs, inputs, config, ... }:
{
  # Decrypt campiglio-password to /run/secrets-for-users/ so it can be used to create the user
#   sops.secrets.campiglio-password.neededForUsers = true;
#   users.mutableUsers = false; #Required for password to be set via sops during system activation!

  users.users.campiglio = {
    isNormalUser = true;
    # hashedPasswordFile = config.sops.secrets.campiglio-password.path;
    extraGroups = [
      # "audio"
      # "video"
    ];

    packages = [ pkgs.home-manager ];
  };

  # Import this user's personal/home configurations
  home-manager.users.campiglio = import ../../../../home/campiglio/${config.networking.hostName}.nix;
}