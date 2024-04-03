{ pkgs ? import <nixpkgs> {} }:

let
#  config = {
#    allowUnfree = true;
#    services.plex = {
#      enable = true;
#      openFirewall = true;
#      dataDir = "/...";
#    };
#  };
#  pkgs = import <nixpkgs> { inherit config; };
in
  pkgs.mkShell {
    nativeBuildInputs = [
#      (pkgs.buildPackages.plex.override (old : { dataDir = "/..."; }))
      pkgs.buildPackages.plex
    ];
    shellHook =
 #      let
 #         cleanUp =
 #           shell_commands:
              ''
                plexmediaserver > /sonarr/mount/plexms.log 2>&1 &
                echo Plex Media Server started.
                rclone mount One1_TV:mainet /sonarr/mount/mount_TV --vfs-cache-mode writes --log-file=/sonarr/mount/rlog_TV.txt &
                rclone mount One1_FD:mainet /sonarr/mount/mount_FD --vfs-cache-mode writes --log-file=/sonarr/mount/rlog_FD.txt &
                rclone mount One1_LM:mainet /sonarr/mount/mount_LM --vfs-cache-mode writes --log-file=/sonarr/mount/rlog_LM.txt &
                rclone mount One1_Col:mainet /sonarr/mount/mount_Col --vfs-cache-mode writes --log-file=/sonarr/mount/rlog_Col.txt &
                echo Rclones mounted.
                trap \
                "
                echo Plex MS stopped.
                echo Execute this to kill rclone: kill \$\(ps aux \| grep \'\[r\]clone\' \| awk \'\{print \$\2\}\'\)
                " \
                EXIT
              '';
    #services.plex = {
    #  enable = true;
    #  openFirewall = true;
    #};
}
