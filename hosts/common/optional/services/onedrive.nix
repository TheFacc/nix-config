# on first run, you will need to run onedrive --synchronize --verbose to authenticate
{ pkgs, config, ... }:
let
    user = "facc";
    homeDir = config.users.users.${user}.home;
    onePkg = pkgs.onedrive;
in
{
    services.onedrive = {
        enable = true;
        package = onePkg;
    };
    systemd.services.onedrive.serviceConfig = { #TODO properly current user
        ExecStart = "${onePkg}/bin/onedrive --monitor --monitor-interval 60 --confdir ${homeDir}/.config/onedrive";    
    };
}
