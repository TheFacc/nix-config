{ pkgs, lib, config, ... }:
{
  # Enable the KDE Plasma Desktop Environment.
  options = { # TODO set as if/else... https://discourse.nixos.org/t/mkif-vs-if-then/28521
    plasma5.enable = lib.mkEnableOption "plasma5";
    plasma6.enable = lib.mkEnableOption "plasma6";
  };

  config = {
    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # plasma5
    services.xserver.displayManager.sddm.enable = lib.mkIf config.plasma5.enable true;
    services.xserver.desktopManager.plasma5.enable = lib.mkIf config.plasma5.enable true;

    # # plasma6 on stable nixos:
    # # - https://discourse.nixos.org/t/using-kde-plasma-6-with-stable-nixos/42525
    # # - https://discourse.nixos.org/t/how-to-use-service-definitions-from-unstable-channel/14767/4
    # disabledModules = [
    #   "services/desktop-managers/plasma6.nix"
    #   "programs/chromium.nix"
    #   "programs/gnupg.nix"
    #   "services/x11/display-managers/sddm.nix"
    #   "security/pam.nix"
    #   "config/krb5/default.nix"
    # ];
    # imports = [
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/services/desktop-managers/plasma6.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/programs/chromium.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/programs/gnupg.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/services/x11/display-managers/sddm.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/security/pam.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/security/krb5/default.nix")
    #   ("${args.inputs.nixpkgs-unstable}/nixos/modules/services/security/intune.nix")
    # ];
    # TODO now properly building only if whole system(?) is on unstable... wait for 24.05?
    # services.xserver.displayManager.sddm.wayland.enable = true; # avoid running X server
    services.desktopManager.plasma6.enable = lib.mkIf config.plasma6.enable true; 
    environment.plasma6.excludePackages = lib.mkIf config.plasma6.enable [
      pkgs.kdePackages.plasma-browser-integration
      # pkgs.kdePackages.konsole
      pkgs.kdePackages.oxygen
    ];
  };
}
