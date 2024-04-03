# on first run, you will need to run onedrive --synchronize --verbose to authenticate
{ outputs, pkgs, config, lib, ... }:
let
    onePkg = pkgs.onedrive;
in
{
    services.onedrive = {
        enable = true;
        package = onePkg;
    };
    systemd.services.onedrive.serviceConfig = { #TODO properly current user
        ExecStart = "${onePkg}/bin/onedrive --monitor --monitor-interval 60 --confdir ${config.users.users.facc.home}/.config/onedrive";    
    };
}
