{ pkgs, ... }:
{

  users.groups.docker = {}; # create "docker" group

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

}
