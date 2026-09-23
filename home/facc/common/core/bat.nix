# https://github.com/sharkdp/bat
# https://github.com/eth-p/bat-extras

{ pkgs, ... }: {
  programs.bat = {
    enable = true;
    config = {
      # Show line numbers, Git modifications and file header (but no grid)
      style = "numbers,changes,header";
      theme = "gruvbox-dark";
      # Bat's own wrap writes real newlines, so a copied line pastes broken.
      wrap = "never";
      # The pager (less) folds lines itself and freezes those breaks, so skip it.
      paging = "never";
    };
    extraPackages = builtins.attrValues {
      inherit (pkgs.bat-extras)

        batgrep # search through and highlight files using ripgrep
        batdiff # Diff a file against the current git index, or display the diff between to files
        batman; # read manpages using bat as the formatter
    };
  };
}
