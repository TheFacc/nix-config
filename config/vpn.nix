{ config, lib, pkgs, ... }: 
let
  user = "facc";
in
{
  users.users.${user}.packages = with pkgs; [
    openvpn
  ];
  services.openvpn.servers = {
    nl = {
      autoStart = false;
      config = "config /home/${user}/VPN/ovpn/TCP/nl2-ovpn-tcp.ovpn";
    };
    us = {
      autoStart = false;
      config = "config /home/${user}/VPN/ovpn/TCP/usla2-ovpn-tcp.ovpn";
    };
    it = {
      autoStart = false;
      config = "config /home/${user}/VPN/ovpn/TCP/it2-ovpn-tcp.ovpn";
    };
  };
}
# then start vpn with:
# sudo systemctl start openvpn-nl.service
