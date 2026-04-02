{ pkgs, ... }:
{
    services.jellyfin = {
        enable = true;
        openFirewall = true;
        group = "media";
    };
    environment.systemPackages = with pkgs; [
        jellyfin
        jellyfin-web
        jellyfin-ffmpeg
    ];
}
