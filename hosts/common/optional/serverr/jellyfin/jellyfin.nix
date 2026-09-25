{ pkgs, ... }:
{
    services.jellyfin = {
        enable = true;
        openFirewall = true;
        group = "media";
    };
    # don't scan (and drop) the library before the media pool is up; start again when it comes back
    systemd.services.jellyfin = {
        unitConfig.RequiresMountsFor = [ "/mnt/mediapool/mainet" ];
        wantedBy = [ "mnt-mediapool-mainet.mount" ];
    };
    environment.systemPackages = with pkgs; [
        jellyfin
        jellyfin-web
        jellyfin-ffmpeg
    ];
}
