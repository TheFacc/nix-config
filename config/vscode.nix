{ config, lib, pkgs, ... }:

let

  # VSCODE
  system = builtins.currentSystem;
 # unstable-pkgs = import <nixos-unstable> { config = { allowUnfree = true; }; }; # doesnt work, installs stable for some reason
  vscodeUns = import (builtins.fetchGit {
      url = "https://github.com/NixOS/nixpkgs";
      ref = "refs/heads/nixpkgs-unstable";
      rev = "36121f3bb095f08bcb92d29fd99e07fd03e195c4"; # v1.87.2 (14-mar-2024)
    }) { config = { allowUnfree = true; }; }; #   { config = config.nixpkgs.config; };

  # EXTENSIONS
  # extensions not in nixpkgs, fixed in time by rev,
  # (v) often waaaaaay more updated than nixpkgs!
  # (x) need to update the rev manually
  extensions =
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      #rev = "cc9b4bc44e8518285a6499959dcf60dfb63dd807"; # 03-jan-2024
      #rev = "9f6b2b21066043d8420dc67798de0a5a5cd2318e"; # 17-feb-2024
      rev = "ebf9b6e2c3252dfcd375a06b69723e0065091568"; # 19-mar-2024
    })).extensions.${system};
  extensionsList = with extensions.vscode-marketplace; [
          # Theme
          monokai.theme-monokai-pro-vscode # -> Filter Spectrum
          # Nix
          bbenoist.nix
          # C++
          # - Microsoft:
#          ms-vscode.cpptools
#          ms-vscode.cpptools-extension-pack
#          ms-vscode.cpptools-themes
         # ms-vscode.makefile-tools # broken?? cant switch
          # - Clangd:
          llvm-vs-code-extensions.vscode-clangd
          # - CMake:
          twxs.cmake
          # ms-vscode.cmake-tools # derivation fails to build with v1.86.2 as of 17-feb-24
          # MATLAB
          mathworks.language-matlab
          # Github
          github.copilot
#          github.copilot-chat #-> forcing old version below
#          github.copilot-labs -> discontinued
          eamodio.gitlens
          #sourcegraph.cody-ai
          # Nuxt
          nuxtr.nuxt-vscode-extentions
          nuxtr.nuxtr-vscode
          nuxt.mdc
          vue.volar
          antfu.goto-alias
  ];
  # force extension version:
  extensionsStable =
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      rev = "0865dd098cd9dc4fa80157d8b19f1c3a242de238"; # 29-feb-2024
    })).extensions.${system};
  extCopilotChat = with extensionsStable.vscode-marketplace; [ github.copilot-chat ];

in
 
{
  environment.systemPackages = [
      # VSCode with extensions:
      #(unstable-pkgs.vscode-with-extensions.override { vscodeExtensions =  extensionsList ++ extCopilotChat; })
      (vscodeUns.vscode-with-extensions.override { vscodeExtensions = extensionsList ++ extCopilotChat; })
      # Packages required by Clangd extension:
      pkgs.llvmPackages_17.clang-unwrapped
  ];
}



