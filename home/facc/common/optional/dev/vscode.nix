# { system ? builtins.currentSystem, inputs, config, pkgs, ... }:
{ pkgs, inputs, ... }:
# should we include this? https://github.com/NixOS/nixpkgs/commit/b2eb5f62a7fd94ab58acafec9f64e54f97c508a6
let
  # system = outputs.system; #TODO inherit system somehow
  system = "x86_64-linux";
  extPk = inputs.nix-vscode-extensions.extensions.${system};
  extensionsList = with extPk.open-vsx; [
        # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/open-vsx-latest.json
          # Theme
          monokai.theme-monokai-pro-vscode # -> Filter Spectrum

          # Tools
          gruntfuggly.todo-tree
          eamodio.gitlens

          # Nix
          bbenoist.nix

          # Nuxt
          nuxtr.nuxt-vscode-extentions
          nuxtr.nuxtr-vscode
          nuxt.mdc
          vue.volar
          # webdev
          pflannery.vscode-versionlens
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode

      ] ++ (with extPk.vscode-marketplace; [
        # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/vscode-marketplace-latest.json
          # C++
          # - Microsoft:
#          ms-vscode.cpptools
#          ms-vscode.cpptools-extension-pack
#          ms-vscode.cpptools-themes
        # ms-vscode.makefile-tools # broken?? cant switch
          # - Clangd:
          # llvm-vs-code-extensions.vscode-clangd # requires pkgs.llvmPackages_17.clang-unwrapped
          # - CMake:
          # twxs.cmake
          # ms-vscode.cmake-tools # derivation fails to build with v1.86.2 as of 17-feb-24
          
          # MATLAB
          # mathworks.language-matlab
          
          # Github
          github.copilot
          # github.copilot-chat #-> forcing 'release' version below, instead of 'latest' which is too new and always incompatible with the current vscode version
#          github.copilot-labs -> discontinued
          #sourcegraph.cody-ai
          
          antfu.goto-alias
      ]) ++ (with extPk.vscode-marketplace-release; [
        # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/vscode-marketplace-release.json
          github.copilot-chat
      ]);

in

{
    # - VSCode
    programs.vscode = {
      enable = true;
      # package = pkgs.vscodium;
      mutableExtensionsDir = false;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = extensionsList;
      userSettings = {
        # "editor.fontFamily" = "'FiraCode Nerd Font', 'FiraCode Nerd Font Mono', 'monospace', monospace";
        "window.titleBarStyle" = "custom";
        "workbench.colorTheme" = "Monokai Pro (Filter Spectrum)";
        "github.copilot.editor.enableAutoCompletions" = true;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "formatting" = {
          "command" = "nixfmt";
        };
      };
    };
}