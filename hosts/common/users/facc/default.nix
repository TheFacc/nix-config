{ pkgs, inputs, config, ... }:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  # Decrypt facc-password to /run/secrets-for-users/ so it can be used to create the user
#   sops.secrets.facc-password.neededForUsers = true;
#   users.mutableUsers = false; # Required for password to be set via sops during system activation!

  users.users.facc = {
    isNormalUser = true;
    # hashedPasswordFile = config.sops.secrets.facc-password.path;
    shell = pkgs.zsh; # default shell
    extraGroups = [
      "wheel"
      # "input"
      # "networkmanager"
      "audio"
      "video"
    ] ++ ifTheyExist [
      "media"
      "docker"
      "git"
      "mysql"
      "network"
    ];

    # openssh.authorizedKeys.keys = [
    #   (builtins.readFile ./keys/id_maya.pub)
    #   (builtins.readFile ./keys/id_mara.pub)
    #   (builtins.readFile ./keys/id_manu.pub)
    #   (builtins.readFile ./keys/id_meek.pub)
    # ];

    packages = [ pkgs.home-manager ];
  };

  # FIXME This should probably be host specific. Also need to confirm that this is the correct place to do this.
#   security.sudo.extraConfig = ''
#     Defaults timestamp_timeout=120 # only ask for password every 120 minutes
#   '';

  # Import this user's personal/home configurations
  home-manager.users.facc = import ../../../../home/facc/${config.networking.hostName}.nix;

}