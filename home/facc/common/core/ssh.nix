{ lib, pkgs, ... }:
{
  # ~/.ssh/config is a nix-store symlink; in user namespaces (AppImages via
  # bwrap, agent sandboxes) root is unmapped, it looks nobody-owned and ssh
  # rejects it. The owner check only applies to the implicit config, not -F.
  # A PATH wrapper (not a shell alias) so subprocesses like T3 Code get it too;
  # ssh keeps the last -F, so an explicit -F still wins.
  home.packages = [
    (lib.hiPrio (pkgs.writeShellScriptBin "ssh" ''
      if [ -e "$HOME/.ssh/config" ]; then
        exec ${pkgs.openssh}/bin/ssh -F "$HOME/.ssh/config" "$@"
      fi
      exec ${pkgs.openssh}/bin/ssh "$@"
    ''))
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      # GitHub keys are picked per directory in git.nix (core.sshCommand).

      # lux
      # "*.google.com" = {
      #   HostName = "source.developers.google.com";
      #   User = "alessio.facincani@ext.luxottica.com";
      #   IdentityFile = "~/.ssh/id_rsa_lux";
      # };
    };
  };
  #  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
