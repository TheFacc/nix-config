{ pkgs, ... }:
#TODO secrets
let
    mountDir = "/var/lib/plex/mount"; 
    mountFlags = "--vfs-cache-mode writes --allow-other"; #TODO avoid --allow-other in mount... (also remove programs.fuse.userAllowOther)
    # TODO ideally: ExecStartPre=mkdirs, ExecStart=rclones, ExecStop=fusermount -u
    # in practice:
    #  - mkdirs seems to not work in ExecStartPre (maybe try more), so set them in mountScript directly, ok
    #  - but most importantly, i cannot manage to unmount correctly. When the service is stopped, ExecStop is not executed, but rclone is still killed, causing the folders to disappear from nautilus, still visible from 'ls' but throwing error 'cannot access: Transport endpoint is not connected'.
    #    I tried putting fusermount everywhere (rcloneUnmountScript fails, rcloneMountScript does nothing but proceeds with next commands), and so if you stop+start service without reboot, it fails cos it cannot mount on the previous directories.
        # ${pkgs.fuse}/bin/fusermount -u ${mountDir}/TV 
        # ${pkgs.fuse}/bin/fusermount -u ${mountDir}/FD 
        # ${pkgs.fuse}/bin/fusermount -u ${mountDir}/LM 
        # ${pkgs.fuse}/bin/fusermount -u ${mountDir}/Col
        # /run/current-system/sw/bin/fusermount -u ${mountDir}/TV
        # /run/current-system/sw/bin/fusermount -u ${mountDir}/FD
        # /run/current-system/sw/bin/fusermount -u ${mountDir}/LM
        # /run/current-system/sw/bin/fusermount -u ${mountDir}/Col
    rcloneMountScript = pkgs.writeScript "rclone_mount.sh" ''
        #!/bin/sh
        /run/current-system/sw/bin/mkdir -p ${mountDir}/TV ${mountDir}/DJ ${mountDir}/FD ${mountDir}/LM ${mountDir}/Col
        ${pkgs.rclone}/bin/rclone mount One1_TV:mainet ${mountDir}/TV ${mountFlags} --log-file=${mountDir}/rlog_TV.txt --daemon
        ${pkgs.rclone}/bin/rclone mount One1_DJ:mainet ${mountDir}/DJ ${mountFlags} --log-file=${mountDir}/rlog_DJ.txt --daemon
        ${pkgs.rclone}/bin/rclone mount One1_FD:mainet ${mountDir}/FD ${mountFlags} --log-file=${mountDir}/rlog_FD.txt --daemon
        ${pkgs.rclone}/bin/rclone mount One1_LM:mainet ${mountDir}/LM ${mountFlags} --log-file=${mountDir}/rlog_LM.txt --daemon
        ${pkgs.rclone}/bin/rclone mount One1_Col:mainet ${mountDir}/Col ${mountFlags} --log-file=${mountDir}/rlog_Col.txt
        wait
    '';
    rcloneUnmountScript = pkgs.writeScript "rclone_unmount.sh" ''
        #!/bin/sh
        /run/current-system/sw/bin/fusermount -u ${mountDir}/TV;
        /run/current-system/sw/bin/fusermount -u ${mountDir}/DJ;
        /run/current-system/sw/bin/fusermount -u ${mountDir}/FD;
        /run/current-system/sw/bin/fusermount -u ${mountDir}/LM;
        /run/current-system/sw/bin/fusermount -u ${mountDir}/Col
    '';
in
{
    ### Add "rclone" to your packages first

    programs.fuse.userAllowOther = true; ##

    # RClone service
    systemd.services.rclone-mount = {
        # Ensure the service starts after the network is up
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];

        # Service configuration
        serviceConfig = {
            Type = "simple";

            # ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${mountDir}/TV && /run/current-system/sw/bin/mkdir -p ${mountDir}/FD && /run/current-system/sw/bin/mkdir -p ${mountDir}/LM && /run/current-system/sw/bin/mkdir -p ${mountDir}/Col";
            # ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${mountDir}/TV ${mountDir}/FD ${mountDir}/LM ${mountDir}/Col";
            # ExecStartPre = "/run/current-system/sw/bin/fusermount -u ${mountDir}/TV";

            # ExecStart = "${pkgs.rclone}/bin/rclone mount One1_TV:mainet ${mountDir}/TV --vfs-cache-mode writes --log-file=${mountDir}/rlog_TV.txt --daemon && \
            #              ${pkgs.rclone}/bin/rclone mount One1_FD:mainet ${mountDir}/FD --vfs-cache-mode writes --log-file=${mountDir}/rlog_FD.txt --daemon && \
            #              ${pkgs.rclone}/bin/rclone mount One1_LM:mainet ${mountDir}/LM --vfs-cache-mode writes --log-file=${mountDir}/rlog_LM.txt --daemon && \
            #              ${pkgs.rclone}/bin/rclone mount One1_Col:mainet ${mountDir}/Col --vfs-cache-mode writes --log-file=${mountDir}/rlog_Col.txt --daemon";
            ExecStart = "${rcloneMountScript}";

            # ExecStop = "/run/current-system/sw/bin/fusermount -u ${mountDir}/TV && \
            #             /run/current-system/sw/bin/fusermount -u ${mountDir}/FD && \
            #             /run/current-system/sw/bin/fusermount -u ${mountDir}/LM && \
            #             /run/current-system/sw/bin/fusermount -u ${mountDir}/Col";
            ExecStop = "${rcloneUnmountScript}";
        
            Restart = "on-failure";
            RestartSec = "10s";
            User = "facc";
            Group = "media";
            Environment = [ "PATH=/run/wrappers/bin/:$PATH" ]; # Required environments
        };
    };
}
