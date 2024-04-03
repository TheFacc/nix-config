{ lib, config, ... }:

let

  arrConfig = {
    sonarr = {
      exportarrPort = "8989";
      url = "localhost:8989";
      #apikey secret
    };
  };

in

{
  options = { arrs.enable = lib.mkEnableOption "Arr services"; };

  config = lib.mkIf config.arrs.enable {
    services = {
      sonarr = {
        enable = true;
        group = "arr";
      };
    };
    users.groups.arr = {};
    # users.users.${user}.extraGroups = [ "arr" ]; #TODO get user somehow
  };

}