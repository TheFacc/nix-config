# OpenCV + GTK enabled (SLAM development)

{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.opencv4.override (old : { enableGtk2 = true; }))
  ];
}
