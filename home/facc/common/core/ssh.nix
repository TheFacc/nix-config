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

      #lux account
      Host *.google.com
        HostName source.developers.google.com
        User alessio.facincani@ext.luxottica.com
        IdentityFile ~/.ssh/id_rsa_lux
    '';
  };
  #  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
