{ pkgs, lib, config, ... }:
let
  hasNvidia = builtins.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  users.groups.docker = {}; # create "docker" group

  # rootful
  virtualisation.docker.enable = true;

  # rootless (issues https://discourse.nixos.org/t/nvidia-docker-container-runtime-doesnt-detect-my-gpu/51336)
  # virtualisation.docker.rootless = {
  #   enable = true;
  #   setSocketVariable = true;
  # };

  hardware.nvidia-container-toolkit.enable = lib.mkIf hasNvidia true;
}
