{ pkgs, ... }:
{
    # note: some settings, like download path, cannot be set here
    #       (if you want, maybe manually with home-manager: dataDir/.config/qBittorrent/qBittorrent.conf)
    services.qBittorrent = {
        enable = true;
        user = "facc";
        group = "media";
        dataDir = "/home/facc"; #TODO get user?
    };
}