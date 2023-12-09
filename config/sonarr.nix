{ config, lib, pkgs, ... }: 
{
  users.users.facc = {
  # packages
  packages = with pkgs; [
      sonarr
      jackett
      bazarr
      qbittorrent-nox
    ];
    extraGroups = [ "sonarr" ];
  };

  # services
  services.sonarr = {
    enable = true;
    openFirewall = true;
  };
  services.jackett = {
    enable = true;
    openFirewall = true;
  };
  services.bazarr = {
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
 
 # rclone cronjob to periodically copy /sonarr/TV to remote
  systemd.timers."rclone-copytv" = {
  wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30m";
      OnUnitActiveSec = "30m";
      Unit = "rclone-copytv.service";
    };
  };
  systemd.services."rclone-copytv" = {
    script = ''
      /etc/profiles/per-user/facc/bin/rclone copy /sonarr/TV One1_TV:mainet/temp --transfers=2 -P -v --log-file=/sonarr/_toup/rcopy.log
      /etc/profiles/per-user/facc/bin/rclone copy /sonarr/_toup/AK_Dir One1_FD:mainet/temp --transfers=1 -P -v --log-file=/sonarr/_toup/rcopy.log
      /etc/profiles/per-user/facc/bin/rclone copy /sonarr/_toup/LZ_MCU One1_LM:mainet/temp --transfers=1 -P -v --log-file=/sonarr/_toup/rcopy.log
      /etc/profiles/per-user/facc/bin/rclone copy /sonarr/_toup/Col One1_Col:mainet/temp --transfers=1 -P -v --log-file=/sonarr/_toup/rcopy.log
      /run/current-system/sw/bin/find /sonarr/TV -type d -empty -delete
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "facc";
    };
  };

}
