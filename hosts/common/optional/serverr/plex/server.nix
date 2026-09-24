{
    services.plex = {
        enable = true;
        openFirewall = true;
        user = "plex";
        group = "media";
        # dataDir = "/var/lib/plexmediaserver";
    };

#trying earlier shutdown
systemd.services.plex = {
  serviceConfig = {
    # 1. Force systemd to send a SIGKILL immediately if the helper doesn't die in 5 seconds
    TimeoutStopSec = "10s";
    
    # 2. Tell systemd to send the termination signal to the entire process group at once
    KillMode = "control-group";
  };
};

}
