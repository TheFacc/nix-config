{ pkgs ? import <nixpkgs> {} }:

  pkgs.mkShell {
    shellHook =
        ''
        echo "Entering the shell tailored to develop a website with Nuxt.js."
        cd "/home/facc/Documents/Nuxt/thefacc.github.io"
#        echo "Launching VSCode in project dir."
#        code .
        '';
    buildInputs = [
      #pkgs.buildPackages.nodejs_21
      pkgs.buildPackages.nodePackages.pnpm
      #pkgs.buildPackages.bun
    ];
}
