# Webdev tools as of dec2025
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.nodejs_24
    pkgs.deno
    pkgs.php
    pkgs.jq
    pkgs.google-chrome # Required by antigravity for automated webapp testing
  ];

  # nix-ld required for automating webapp testing
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Add common libraries used by Chrome/Playwright
      stdenv.cc.cc
      glib
      nss
      nspr
      atk
      at-spi2-atk
      cups
      libdrm
      dbus
      libxkbcommon
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      mesa
      expat
      pango
      cairo
      alsa-lib
    ];
  };
}
