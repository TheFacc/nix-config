{ config, lib, pkgs, ... }: 
{
  users.users.facc.packages = with pkgs; [
    openvpn
  ];
  services.openvpn.servers = {
    nl = {
      autoStart = false;
      config = "config /home/facc/VPN/ovpn/TCP/nl2-ovpn-tcp.ovpn";
    };
    us = {
      autoStart = false;
      config = "config /home/facc/VPN/ovpn/TCP/usla2-ovpn-tcp.ovpn";
    };
    it = {
      autoStart = false;
      config = "config /home/facc/VPN/ovpn/TCP/it2-ovpn-tcp.ovpn";
    };
  };
}
