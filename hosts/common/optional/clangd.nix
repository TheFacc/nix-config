# Clangd is a language server for C++ that uses Clang as a backend.
# Required by VSCode Clangd extension.

{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
      llvmPackages_17.clang-unwrapped
    ];
}
