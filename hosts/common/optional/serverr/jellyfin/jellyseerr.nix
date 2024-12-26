# Jellyseer - manage requests
# { pkgs, ... }:
{
    services.jellyseerr = {
        enable = true;
        openFirewall = true;
#         port = 5055;
    };
}
