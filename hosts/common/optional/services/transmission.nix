{ config, ... }:
{
    services.transmission = {
        enable = true;
        # user = "media";
        group = "media";
        settings = {
            incomplete-dir-enabled = true;
            # incomplete-dir = "${config.services.transmission.home}/_incomplete";
            download-dir = "${config.services.transmission.home}/Downloads";
        };
    };
}