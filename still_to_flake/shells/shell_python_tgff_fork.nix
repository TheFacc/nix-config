{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = python-packages: with python-packages; [
    pip
    python-telegram-bot
    pyrogram
    tgcrypto
    python-dotenv
  ];
  python-with-my-packages = pkgs.python310.withPackages my-python-packages;
in

  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = [
      python-with-my-packages
    ];

}
