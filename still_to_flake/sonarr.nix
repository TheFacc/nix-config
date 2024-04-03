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

  # NixOS services
  services.sonarr = {
    enable = true;
    openFirewall = true;
  };
#  services.jackett = { # run using docker cos of flaresolverr issues
#    enable = true;
#    openFirewall = true;
#  };
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

  # Docker services
#  systemd.services.jackett-docker = {
#    script = ''
#      /run/current-system/sw/bin/docker-compose -f /sonarr/Apps/Jackett/docker-compose.yml up
#    '';
#    wantedBy = ["multi-user.target"];
#    after = ["docker.service" "docker.socket"];
#  };
#  systemd.services.flaresolverr-docker = {
#    script = ''
#      /run/current-system/sw/bin/docker-compose -f /sonarr/Apps/FlareSolverr/docker-compose.yml up
#    '';
#    wantedBy = ["multi-user.target"];
#    after = ["docker.service" "docker.socket"];
#  };
  # Docker services, declaratively (actually podman)
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers = {
     jackett = {
       image = "lscr.io/linuxserver/jackett:latest";
       ports = ["127.0.0.1:9117:9117"];
       volumes = ["/sonarr/Apps:/config"];
       environment = {
         PGID="1000";
         PUID="1000";
         TZ="Europe/Rome";
#         AUTO_UPDATE=true #optional
#         RUN_OPTS= #optional
       };
     };
     flaresolverr = {
       image = "ghcr.io/flaresolverr/flaresolverr:latest";
       ports = ["127.0.0.1:8191:8191"];
       environment = {
         LOG_LEVEL="info";
         LOG_HTML="false";
         CAPTCHA_SOLVER="none";
         TZ="Europe/Rome";
       };
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
      /run/current-system/sw/bin/mkdir /sonarr/TV
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "facc";
    };
  };

}
