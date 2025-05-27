{ inputs, ... }:
# taken from: https://github.com/nmasur/dotfiles/blob/master/modules/nixos/services/arr.nix
# source file config example: https://github.com/DamienCassou/nixpkgs/blob/master/pkgs/servers/sonarr/default.nix
let

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
  system = "x86_64-linux";
  sonarrDir = "/var/lib/sonarr/.config/NzbDrone";
  radarrDir = "/var/lib/radarr/.config/Radarr";
  flaresolverrPath = inputs.nur.legacyPackages.${system}.repos.xddxdd.flaresolverr-21hsmw;

in

{
  imports = [
    ../services/dupsvc.nix
  ];

  # options = { arrs.enable = lib.mkEnableOption "Arr services"; };

  config = {#lib.mkIf config.arrs.enable {

    services = {
      # indexers
      prowlarr= {
        enable = true;
#         group = "media"; # option not available ;/ set below
      };

      # getters
      sonarr = {
        enable = true;
        group = "media";
        dataDir = sonarrDir;
      };
      radarr = {
        enable = true;
        # openFirewall = true; # todo, to try if fixes reachabiliity from nixossone
        group = "media";
        dataDir = radarrDir;
      };
    };

    # duplicated services for 4K content
    # _module.args = {
    #   nixpkgs = inputs.nixpkgs;
    # };
    systemd.tmpfiles.rules = [
      "d ${sonarrDir}-4K 0700 sonarr media -"
      "d ${radarrDir}-4K 0700 radarr media -"
    ];
    dupsvc.services = {
      sonarr = {
        enable = true;
        user = "sonarr";
        group = "media"; # make sure this exists
        settings.server.port = 8984;
        dataDir = "${sonarrDir}-4K";
      };
      radarr = {
        enable = true;
        user = "radarr";
        group = "media"; # make sure this exists
        settings.server.port = 7874;
        dataDir = "${radarrDir}-4K";
      };
    };

    # cloudflare bypass
    systemd.services.flaresolverr = {
      after = [ "network.target" ];
      serviceConfig = {
        Group = "media";
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
        ExecStart = "${flaresolverrPath}/bin/flaresolverr";
      };
      wantedBy = [ "multi-user.target" ];
    };

    users.groups.media = {};

    # prowlarr currently does not have .group option, so i add its user to the group manually
    users.users.prowlarr = {
      isSystemUser = true;
      group = "media";
    };
  };

}
