{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kdePackages.kcalc
  ];
}
