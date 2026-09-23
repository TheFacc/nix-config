# Run AppImages directly, including desktop-file protocol handlers.
{
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
}
