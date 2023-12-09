{ config, lib, pkgs, ... }:

let

  system = builtins.currentSystem;
  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
  # extensions not in nixpkgs, fixed in time by rev,
  # (v) often waaaaaay more updated than nixpkgs!
  # (x) need to update the rev manually
  extensions =
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      rev = "f0be3d039fd7500d927b7584ddd632e5e5dce45f"; # 06-dic-2023
    })).extensions.${system};
  extensionsList = with extensions.vscode-marketplace; [
          # Theme
          monokai.theme-monokai-pro-vscode # -> Filter Spectrum
          # C++
          # - Microsoft:
#          ms-vscode.cpptools
#          ms-vscode.cpptools-extension-pack
#          ms-vscode.cpptools-themes
          # - Clangd:
          llvm-vs-code-extensions.vscode-clangd
          # - CMake:
          twxs.cmake
          ms-vscode.cmake-tools
          # Github
          github.copilot
#          github.copilot-chat
          github.copilot-labs
          eamodio.gitlens
  ];
  extensions184 =
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      rev = "bc5ea072fb52bacc3a48bc6e716c373b44d76088"; # 01-nov-2023, for latest copchat compatible with 1.84
    })).extensions.${system};
  extCopilotChat = with extensions184.vscode-marketplace; [ github.copilot-chat ];

in
 
{
  environment.systemPackages = with pkgs; [
      # VSCode with extensions:
      (unstable.vscode-with-extensions.override { vscodeExtensions =  extensionsList ++ extCopilotChat; })
      # Packages required by Clangd extension:
      llvmPackages_16.clang-unwrapped
      libstdcxx5 # probably useless idk, tried to fix basic headers missing
  ];
}



