# facc on nixpad — minimal home profile for Niri + DMS VM testing.
{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    common/core

    common/optional/desktops/catppuccin.nix
    common/optional/browsers/firefox.nix

    {
      home = {
        username = "facc";
        homeDirectory = "/home/facc";
      };
    }
  ];

  config.nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };
}
