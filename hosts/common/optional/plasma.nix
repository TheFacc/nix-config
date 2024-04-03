# { pkgs, ... } @ args:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  # plasma5
  #services.xserver.displayManager.sddm.enable = true;
  #services.xserver.desktopManager.plasma5.enable = true;
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
  # forget it, lets just get unstable
  services.xserver.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true; 
}
