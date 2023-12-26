{ config, lib, pkgs, ... }: 
{
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
#  users.users.facc.extraGroups = [ "docker" ]; # https://discourse.nixos.org/t/docker-compose-on-nixos/17502/4
  environment.systemPackages = [ pkgs.docker-compose ];
}
