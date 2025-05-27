{ pkgs, ... }:
# { extraOptions ? [] }:
let
    ops = [
        "defaults"
        "noatime"
        "lazytime"
        "commit=60"
        "nofail" # keep going, spinup might be slow
        "data=ordered"
#         "errors=remount-ro" # mount read-only if error
        "x-systemd.automount"
        "x-systemd.mount-timeout=20s"
    ];
in
{
    # physical disks
    fileSystems."/mnt/media/16TB" = {
        device = "/dev/disk/by-uuid/aead249c-8fbf-44f1-b9d5-a80c6dd3c160";
        fsType = "ext4";
        options = ops;# ++ extraOptions;
    };
    fileSystems."/mnt/media/16TBb" = {
        device = "/dev/disk/by-uuid/05525013-c780-4fb2-ac6d-8839cf01bcc8";
        fsType = "ext4";
        options = ops;# ++ extraOptions;
    };

    # pool them
    environment.systemPackages = [
        pkgs.mergerfs
    ];
    fileSystems."/mnt/mediapool" = {
        fsType = "fuse.mergerfs";
        device = "/mnt/media/*";
        options = [
            "defaults"
            "category.create=epmfs" # existing path, most free space (pre-populate tree as needed!)
#             "allow_other" # allow access to non-root (im using group policies instead)
            "use_ino" # preserve inode numbers, important for hardlinks
            "cache.files=off" # ensure up-to-date directory listings
            "dropcacheonclose=true"
            "moveonenospc=true" # try next drive if one is full during a write
            "minfreespace=30G"
            "x-systemd.automount"
            "x-systemd.mount-timeout=20s"
        ];
    };
}
