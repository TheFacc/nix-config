{ config, lib, pkgs, ... }: 
{
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  users.users.facc.extraGroups = [ "docker" ];
}
