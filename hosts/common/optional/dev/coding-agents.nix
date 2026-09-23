# Stable Claude Code and Codex on the system PATH (quota plugin).
# T3 Code keeps its own npm copies in ~/.local/share/t3code-providers and
# puts that bin directory ahead of /run/current-system/sw/bin.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.claude-code
    pkgs.codex
  ];
}
