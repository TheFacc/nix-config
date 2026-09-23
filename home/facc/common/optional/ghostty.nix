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
    };
  };

  # Flavor follows catppuccin.flavor (mocha on nixpad).
  catppuccin.ghostty.enable = true;

  home.sessionVariables = {
    TERMINAL = lib.mkForce "ghostty";
    # Ghostty ships this terminfo. Over SSH, a host without it needs
    # `term = xterm-256color` in the settings above.
    TERM = lib.mkForce "xterm-ghostty";
  };
}
