{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = python-packages: with python-packages; [
    python-telegram-bot
    telethon
  ];
  python-with-my-packages = pkgs.python310.withPackages my-python-packages;

in

  pkgs.mkShell {
    nativeBuildInputs = [
      python-with-my-packages
    ];
}
