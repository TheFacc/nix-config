# https://github.com/ajeetdsouza/zoxide
# https://wiki.nixos.org/wiki/Zoxide

{
    programs.zoxide = {
        enable = true;
        options = [
            "--cmd cd"
        ];
    };

    # fuzzy search
    programs.fzf = {
        enable = true;
        enableZshIntegration = true;
    };
    # e.g. interactive list of available packages:    nix-env -qa | fzf
}
