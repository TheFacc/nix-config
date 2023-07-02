{ lib, ... }:

{
  programs.steam = {
   enable = true;
   remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
   dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-original"
    "steam-runtime"
  ];
  hardware.opengl.driSupport32Bit = true; # https://github.com/NixOS/nixpkgs/issues/47932#issuecomment-447508411
  
  # Steam controller
  hardware.steam-hardware.enable = true;

  # non-steam tool
  #  users.users.facc.packages = ...? pkgs.steamcontroller;
}
