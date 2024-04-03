{ pkgs, lib, config, ... }:
{
  programs.git = {
    enable = true;
    # package = pkgs.gitAndTools.gitFull;
    # aliases = { };
    extraConfig = {
      init.defaultBranch = "main";
      "user.TheFacc" = {
        name = "TheFacc";
        email = "imthefacc@gmail.com";
      };
      "user.AFLux" = {
        name = "Alessio Facincani";
        email = "alessio.facincani@ext.luxottica.com";
        # signing.key = "-----";
      };
      # url = {
      #   "ssh://git@github.com" = {
      #     insteadOf = "https://github.com";
      #   };
      #   "ssh://git@gitlab.com" = {
      #     insteadOf = "https://gitlab.com";
      #   };
      # };

      # #TODO sops - Re-enable once sops setup complete
      # commit.gpgSign = false;
      # gpg.program = "${config.programs.gpg.package}/bin/gpg2";
    };
    # enable git Large File Storage: https://git-lfs.com/
    # lfs.enable = true;
    ignores = [ ".direnv" "result" ];
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
