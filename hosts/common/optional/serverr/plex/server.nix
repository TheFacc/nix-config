{
    services.plex = {
        enable = true;
        openFirewall = true;
        user = "plex";
        group = "media";
        # dataDir = "/var/lib/plexmediaserver";
    };
}
