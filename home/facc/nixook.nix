# main config for facc on galaxy book4
# references all core stuff and most optional stuff

{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    #################### Required Configs ####################
    common/core #required

    #################### Host-specific Optional Configs ####################
    # common/optional/helper-scripts

    # Browsers
    common/optional/browsers/firefox.nix
    common/optional/browsers/brave.nix

    # Dev
    common/optional/dev/vscode.nix

    # Entertainment
    ../common/optional/mpv.nix
  ];

  config.nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) outputs.allowed-unfree-packages;
  };
}