{ pkgs, ... }:
let
  scripts = {
    # # FIXME: I currently get the following warnings:
    # # svn: warning: cannot set LC_CTYPE locale
    # # svn: warning: environment variable LANG is en_US.UTF-8
    # # svn: warning: please check that your locale name is correct
    # copy-github-subfolder = pkgs.writeShellApplication {
    #   name = "copy-github-subfolder";
    #   runtimeInputs = with pkgs; [ subversion ];
    #   text = builtins.readFile ./copy-github-subfolder.sh;
    # };
    # linktree = pkgs.writeShellApplication
    #   {
    #     name = "linktree";
    #     runtimeInputs = with pkgs; [ ];
    #     text = builtins.readFile ./linktree.sh;
    #   };

    stop-services = pkgs.writeShellApplication
      {
        name = "stop-services";
        text = builtins.readFile ./stop-services.sh;
      };
    start-services = pkgs.writeShellApplication
      {
        name = "start-services";
        text = builtins.readFile ./start-services.sh;
      };
  };
in
{
  home.packages = builtins.attrValues {
    inherit (scripts)
      # copy-github-subfolder
      # linktree
      stop-services
      start-services;
  };
}
