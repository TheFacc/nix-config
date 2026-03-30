{ pkgs, lib, config, ... } @ args:
let
  os = args.osConfig or null;
in
{
  programs.git = {
    enable = true;
    # package = pkgs.gitAndTools.gitFull;
    # aliases = { };
    settings = {
      init.defaultBranch = "main";
      "user.TheFacc" = {
        name = "TheFacc";
        # email: NixOS sops template git-user-thefacc-email (include below), not here. Yeah i know, shhh
      };
#       "user.AFLux" = {
#         name = "Alessio Facincani";
#         email = "alessio.facincani@ext.luxottica.com";
#         # signing.key = "-----";
#       };
      # url = {
      #   "ssh://git@github.com" = {
      #     insteadOf = "https://github.com";
      #   };
      #   "ssh://git@gitlab.com" = {
      #     insteadOf = "https://gitlab.com";
      #   };
      # };

      # commit.gpgSign = false;
      # gpg.program = "${config.programs.gpg.package}/bin/gpg2";
    };
    # enable git Large File Storage: https://git-lfs.com/
    # lfs.enable = true;
    ignores = [ ".direnv" "result" ];
    signing.format = "openpgp";
    # Rendered by NixOS sops (root key); path is runtime, not the nix store.
    includes = lib.optionals (os != null && os.local.hasSopsSecrets) [
      { path = os.sops.templates."git-user-thefacc-email".path; }
    ];
  };
  programs.gh = {
    enable = true;
    extensions = [
      # pkgs.gh-copilot
    ];
  };
    #   home.packages = with pkgs; [
    #   github-desktop
    #   gh
    # ];
}
