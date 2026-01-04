# Webdev tools as of dec2025, chrome required by antigravity for automated webapp testing
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.nodejs_24
    pkgs.deno
    pkgs.php
    pkgs.jq
    pkgs.google-chrome
  ];
}
