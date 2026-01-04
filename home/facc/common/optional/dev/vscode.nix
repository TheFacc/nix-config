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

          # C++
          llvm-vs-code-extensions.vscode-clangd
          ms-vscode.cmake-tools

          # Python
          ms-python.python

          # Nuxt
          nuxtr.nuxt-vscode-extentions 
          nuxtr.nuxtr-vscode
          nuxt.mdc
          vue.volar
          # webdev
          pflannery.vscode-versionlens
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode
          devsense.phptools-vscode # php
          natizyskunk.sftp # sftp
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

          # MATLAB
          # mathworks.language-matlab
    
          antfu.goto-alias # + custom userSettings
          # heminei.pro-deployer # ftp
      ]) ++ (with extPk.vscode-marketplace-release; [
        # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/vscode-marketplace-release.json
        #   github.copilot #### disabled since april2025 cos i cannot allow them as unfree for some reason now. see obsidian
        #   github.copilot-chat
      ]);

in

{
  # - VSCode
  programs.vscode = {
    enable = true;
    package = pkgs.antigravity;

    ## TODO required until they add antigravity to the supported forks
    nameShort = "Antigravity";
    dataFolderName = ".antigravity";
    ##

    mutableExtensionsDir = true; ######## TODO should be false for nixy, but antigravity cannot load extensions otherwise
    profiles.default = {
      extensions = extensionsList;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      userSettings = {
        # "editor.fontFamily" = "'FiraCode Nerd Font', 'FiraCode Nerd Font Mono', 'monospace', monospace";
        "window.titleBarStyle" = "custom";
        "workbench.colorTheme" = "Monokai Pro (Filter Spectrum)";
        "github.copilot.editor.enableAutoCompletions" = true;
        "diffEditor.ignoreTrimWhitespace" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "formatting" = {
          "command" = "nixfmt";
        };
        "editor.gotoLocation.multipleDefinitions" = "goto";
      };
    };
  };
}