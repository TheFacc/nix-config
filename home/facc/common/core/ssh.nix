{ ... }:
{
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
