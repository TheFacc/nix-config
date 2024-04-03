{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    # emergent
    noto-fonts
    nerdfonts # loads the complete collection. look into override for FiraMono or potentially mononoki
    meslo-lgs-nf
    # claudio
    inter
    lato
    inconsolata
    liberation_ttf
    # iosevka
    # fira
    # fira-code
  ];

}
