{ lib, config, pkgs, ... }:
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
      # indexers
      prowlarr.enable = true;

      # getters
      sonarr = {
        enable = true;
        group = "media";
      };
      radarr = {
        enable = true;
        group = "media";
      };
    };

    # cloudflare bypass
    systemd.services.flaresolverr = {
      after = [ "network.target" ];
      serviceConfig = {
        User = "sonarr";
        Group = "media";
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
        ExecStart = "${config.nur.repos.xddxdd.flaresolverr}/bin/flaresolverr";
      };
      wantedBy = [ "multi-user.target" ];
    };

    users.groups.media = {};
    # users.users.${config.user}.extraGroups = [ "media" ]; #TODO get user somehow... or set elsewhere
  };

}
