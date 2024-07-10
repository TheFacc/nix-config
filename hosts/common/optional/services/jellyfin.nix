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
#         jellyfin-ffmpeg
    ];
}
