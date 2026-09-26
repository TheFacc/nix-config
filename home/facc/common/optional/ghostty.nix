# Ghostty
{ lib, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # MesloLGS NF is already installed for Powerlevel10k.
      font-family = "MesloLGS NF";
      font-size = 12;
      # Niri draws the frame; skip the GTK header bar.
      gtk-titlebar = false;
      confirm-close-surface = false;
      async-backend = "epoll";
      # The `ssh` wrapper from shell integration: installs the xterm-ghostty
      # terminfo on the remote on first connect (cached per host), and falls
      # back to TERM=xterm-256color when it can't.
      shell-integration-features = "ssh-terminfo,ssh-env";
    };
  };

  # Flavor follows catppuccin.flavor (mocha on nixpad).
  catppuccin.ghostty.enable = true;

  home.sessionVariables = {
    TERMINAL = lib.mkForce "ghostty";
  };
}
