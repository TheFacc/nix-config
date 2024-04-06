{ lib, config, ... }:
# taken from: https://github.com/nmasur/dotfiles/blob/master/modules/nixos/services/arr.nix
# source file config example: https://github.com/DamienCassou/nixpkgs/blob/master/pkgs/servers/sonarr/default.nix
# let

#   arrConfig = {
#     prowlarr = {
#       exportarrPort = "9709";
#       url = "localhost:9696";
#       # apiKey = config.secrets.prowlarrApiKey.dest;
#     };
#     sonarr = {
#       exportarrPort = "8989";
#       url = "localhost:8989";
#       # apiKey = config.secrets.sonarrApiKey.dest;
#     };
#   };

# in

{
  # options = { arrs.enable = lib.mkEnableOption "Arr services"; };

  config = {#lib.mkIf config.arrs.enable {

    services = {
      prowlarr.enable = true;
      sonarr = {
        enable = true;
        group = "media";
      };
    };

    users.groups.media = {};
    # users.users.${config.user}.extraGroups = [ "media" ]; #TODO get user somehow... or set elsewhere
  };

}