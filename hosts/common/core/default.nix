{ inputs, outputs, pkgs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./locale.nix # localization settings
    ./nix.nix # nix settings and garbage collection
    ./sops.nix # secrets management
    ./sops-meta.nix
    ./zsh.nix # load a basic shell just in case we need it without home-manager
    ./1.1.1.1.nix # cloudflare dns
    
    # ./services/auto-upgrade.nix # auto-upgrade service

  ] ++ (builtins.attrValues outputs.nixosModules);

  # Ghostty's terminfo on every host, so `ssh` from Ghostty (TERM=xterm-ghostty)
  # doesn't warn "can't find terminal definition".
  environment.systemPackages = [ pkgs.ghostty.terminfo ];

  home-manager.sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
  home-manager.extraSpecialArgs = { inherit inputs outputs; };

#   nixpkgs = {
#     # you can add global overlays here
#     overlays = builtins.attrValues outputs.overlays;
#     config = {
#       allowUnfree = true;
#     };
#   };

#   hardware.enableRedistributableFirmware = true;
}