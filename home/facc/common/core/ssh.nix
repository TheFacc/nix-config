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

      # git@github.com-facc:TheFacc/repo.git
      "github.com-facc" = {
        HostName = "github.com";
        User = "TheFacc";
        IdentityFile = "~/.ssh/id_rsa";
        IdentitiesOnly = true;
      };

      # git@github.com-becq:Alessio-Becquerel/repo.git
      "github.com-becq" = {
        HostName = "github.com";
        User = "Alessio-Becquerel";
        IdentityFile = "~/.ssh/id_becq";
        IdentitiesOnly = true;
      };

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
