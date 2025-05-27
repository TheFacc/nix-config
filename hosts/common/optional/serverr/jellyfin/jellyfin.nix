{ pkgs, ... }:
{
    services.jellyfin = {
        enable = true;
        openFirewall = true;
#         port = 8096;
        user = "facc";
        group = "media";
#         dataDir
    };
    environment.systemPackages = with pkgs; [
        jellyfin
        jellyfin-web
        jellyfin-ffmpeg
    ];

    # daily backup
    systemd.timers."jellyfin-backup" = {
        wantedBy = [ "timers.target" ];
        partOf = [ "jellyfin-backup.service" ];
        timerConfig = {
            OnCalendar = "05:00";
            Persistent = "true";
            Unit = "jellyfin-backup.service";
        };
    };
    systemd.services."jellyfin-backup" = {
        description = "Backup Jellyfin config folder";
        path = with pkgs; [ bash ];
        serviceConfig = {
            Type = "simple";
            User = "facc";
#             ExecStart = "/home/facc/dotfiles/nix-config/hosts/common/optional/services/";
        };
        script = ''
            bash /home/facc/dotfiles/nix-config/hosts/common/optional/serverr/jellyfin/jellyfin-backup.sh
            echo " ! jellyfin-backup service executed ! "
        '';
#         restartIfChanged = false;
#         wantedBy = [ "multi-user.target" ];
    };
}
