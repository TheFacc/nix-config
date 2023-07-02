{ config, lib, pkgs, ... }: 
{
  users.users.facc = {
    packages = with pkgs; [
      sonarr
      jackett
      qbittorrent-nox
    ];
    extraGroups = [ "sonarr" ];
  };
  services.sonarr = {
    enable = true;
    openFirewall = true;
  };
  services.jackett = {
    enable = true;
    openFirewall = true;
  };
  systemd.services.qbittorrent-nox = {
    enable = true;
    serviceConfig = {
      User = "sonarr";
      Group = "sonarr";
    };
  };
}
