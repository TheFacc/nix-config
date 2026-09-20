# Optional flake-based DMS + niri HM integration (heavier; needs niri-flake).
# Enable by importing this from a host home config instead of the nixpkgs dms.nix system module.
{ inputs, lib, ... }:
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
    inputs.niri.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = lib.mkDefault false;

    niri = {
      enableKeybinds = false;
      enableSpawn = true;
      includes = {
        enable = true;
        filesToInclude = [
          "alttab"
          "binds"
          "colors"
          "cursor"
          "layout"
          "outputs"
          "windowrules"
          "wpblur"
        ];
      };
    };

    enableDynamicTheming = true;
    enableCalendarEvents = true;
    enableSystemMonitoring = true;
    enableAudioWavelength = true;
    enableVPN = false;
  };

  systemd.user.services.niri-flake-polkit.enable = false;
}
