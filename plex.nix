{ config, pkgs, ... }:
{
  ## SERVER
  ## https://scholz.ruhr/blog/keeping-plex-up-to-date-on-nixos/
  #services.plex = let
  #  master = import
  #      (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/master)
  #      { config = config.nixpkgs.config; };
  #in
  #  {
  #    enable = true;
  #    openFirewall = true;
  #    package = master.plex;
  #  };

  ## PLAYER
  services.flatpak = {
    enable = true;
  };
}
