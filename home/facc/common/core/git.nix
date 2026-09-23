{ pkgs, lib, config, ... } @ args:
let
  os = args.osConfig or null;
in
{
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      user.name = "TheFacc";
      core.sshCommand = "ssh -i ~/.ssh/id_facc -o IdentitiesOnly=yes";
      url."git@github.com:".insteadOf = "https://github.com/";  # HTTPS remotes use your key too
    };
    ignores = [ ".direnv" "result" ];
    signing.format = "openpgp";
    # Emails are rendered by NixOS sops (runtime paths, not the nix store). Later includes win.
    includes =
      let
        sops = os != null && os.local.hasSopsSecrets;
        work = "gitdir:~/Documents/Bll/";   # every repo under here is Becquerel
      in
      lib.optionals sops [ { path = os.sops.templates."git-user-thefacc-email".path; } ]
      ++ [{
        condition = work;
        contents = {
          user.name = "Alessio-Becquerel";
          core.sshCommand = "ssh -i ~/.ssh/id_becq -o IdentitiesOnly=yes";
        };
      }]
      ++ lib.optionals sops [ { condition = work; path = os.sops.templates."git-user-becq-email".path; } ];
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false;   # git no longer goes through gh
  };
    #   home.packages = with pkgs; [
    #   github-desktop
    #   gh
    # ];
}
