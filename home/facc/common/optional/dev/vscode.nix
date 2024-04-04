# { system ? builtins.currentSystem, inputs, config, pkgs, ... }:
# { outputs, ... }:
# should we include this? https://github.com/NixOS/nixpkgs/commit/b2eb5f62a7fd94ab58acafec9f64e54f97c508a6
let
  # system = outputs.system; #TODO inherit system somehow
  system = "x86_64-linux";
  VSCextensions = #lib.genAttrs ss (system:
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      #rev = "cc9b4bc44e8518285a6499959dcf60dfb63dd807"; # 03-jan-2024
      #rev = "9f6b2b21066043d8420dc67798de0a5a5cd2318e"; # 17-feb-2024
      rev = "ebf9b6e2c3252dfcd375a06b69723e0065091568"; # 19-mar-2024 #TODO this looks awful now right uhm think about it
    })).extensions.${system};
  extensionsList = with VSCextensions.vscode-marketplace; [
          # Theme
          monokai.theme-monokai-pro-vscode # -> Filter Spectrum
          gruntfuggly.todo-tree

          # Nix
          bbenoist.nix
          
          # C++
          # - Microsoft:
#          ms-vscode.cpptools
#          ms-vscode.cpptools-extension-pack
#          ms-vscode.cpptools-themes
        # ms-vscode.makefile-tools # broken?? cant switch
          # - Clangd:
          llvm-vs-code-extensions.vscode-clangd # requires pkgs.llvmPackages_17.clang-unwrapped
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
          # webdev
          pflannery.vscode-versionlens
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode
  ];

  # force extension version:
  extensionsStable =# lib.genAttrs outputs.systems (system:
    (import (builtins.fetchGit {
      url = "https://github.com/nix-community/nix-vscode-extensions";
      ref = "refs/heads/master";
      rev = "0865dd098cd9dc4fa80157d8b19f1c3a242de238"; # 29-feb-2024
    })).extensions.${system};
  extCopilotChat = with extensionsStable.vscode-marketplace; [ github.copilot-chat ];

in

{
    # - VSCode
    programs.vscode = {
      enable = true;
      # package = pkgs.vscodium;
      extensions = extensionsList ++ extCopilotChat;
    };
}
