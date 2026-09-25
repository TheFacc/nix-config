{ config, pkgs, ... }:
let
  catppuccinFlavor = config.catppuccin.flavor;
  catppuccinKonsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
  home.packages = [
#     (pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; })
    pkgs.nerd-fonts.fira-code
  ];

  # plasma-manager's customColorSchemes only takes a path or an attrset now,
  # so link the upstream colorscheme file straight into konsole's data dir
  xdg.dataFile."konsole/catppuccin-${catppuccinFlavor}.colorscheme".source =
    "${catppuccinKonsole}/themes/catppuccin-${catppuccinFlavor}.colorscheme";

  programs.konsole = {
    enable = true;

    defaultProfile = "Heitor";

    profiles = {
      Heitor = {
        colorScheme = "catppuccin-${catppuccinFlavor}";
        font = {
          name = "FiraCode Nerd Font";
          size = 12;
        };
      };
    };
  };
}
