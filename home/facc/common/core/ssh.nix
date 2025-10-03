{ outputs, lib, ... }:
{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      #github account
      Host *.github.com
        HostName github.com
        User TheFacc
        IdentityFile ~/.ssh/id_rsa

#       #lux account
#       Host *.google.com
#         HostName source.developers.google.com
#         User alessio.facincani@ext.luxottica.com
#         IdentityFile ~/.ssh/id_rsa_lux
    '';

    # default values are going deprecated:
    enableDefaultConfig = false;
    matchBlocks."*" = { forwardAgent = false; addKeysToAgent = "no"; compression = false; serverAliveInterval = 0; serverAliveCountMax = 3; hashKnownHosts = false; userKnownHostsFile = "~/.ssh/known_hosts"; controlMaster = "no"; controlPath = "~/.ssh/master-%r@%n:%p"; controlPersist = "no"; };
  };
  #  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
