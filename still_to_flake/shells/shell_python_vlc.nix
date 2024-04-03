{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = python-packages: with python-packages; [
    pip
    pipx # --> pipx install trakt-scrobbler
  ];
  python-with-my-packages = pkgs.python310.withPackages my-python-packages;

in

  pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.buildPackages.vlc
      python-with-my-packages
    ];
    shellHook = ''
       python3 -m pipx ensurepath
       python3 -m pipx install trakt-scrobbler
       trakts status
    '';
}
