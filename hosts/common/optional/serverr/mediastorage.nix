{ pkgs, ... }:
# { extraOptions ? [] }:
let
    # no x-systemd.automount: a missing disk must leave a plain empty dir, not an autofs stub
    # that hangs 10s on every access (mergerfs also counts the stub as "mounted")
    ops = [
        "defaults"
        "noatime"
        "lazytime"
        "commit=60"
        "nofail" # keep going, spinup might be slow
        "data=ordered"
#         "errors=remount-ro" # mount read-only if error
        "x-systemd.device-timeout=10s" # give up quickly on a detached disk
        "x-systemd.mount-timeout=20s"
    ];
in
{
    # physical disks
    fileSystems."/mnt/media/16TB" = {
        device = "/dev/disk/by-uuid/aead249c-8fbf-44f1-b9d5-a80c6dd3c160";
        fsType = "ext4";
        options = ops; # ++ extraOptions;
    };
    fileSystems."/mnt/media/16TBb" = {
        device = "/dev/disk/by-uuid/05525013-c780-4fb2-ac6d-8839cf01bcc8";
        fsType = "ext4";
        options = ops; # ++ extraOptions;
    };

    # pool the `mainet` dir of each disk into /mnt/mediapool/mainet (same paths as the old whole-disk pool).
    # Branches are subdirs on purpose: while a disk is unplugged its <disk>/mainet doesn't exist,
    # so mergerfs skips it (nothing lands on the system SSD, nothing hangs), and it's picked up
    # again as soon as the disk is mounted, no pool remount needed.
    # Never create /mnt/media/<disk>/mainet by hand while that disk is unmounted.
    environment.systemPackages = [
        pkgs.mergerfs
    ];
    fileSystems."/mnt/mediapool/mainet" = {
        fsType = "fuse.mergerfs";
        device = "/mnt/media/16TB/mainet:/mnt/media/16TBb/mainet";
        options = [
            "defaults"
            "nofail"
            "category.create=epmfs" # existing path, most free space (pre-populate tree as needed!)
#             "allow_other" # allow access to non-root (im using group policies instead)
            "use_ino" # preserve inode numbers, important for hardlinks
            "cache.files=off" # ensure up-to-date directory listings
            "dropcacheonclose=true"
            "moveonenospc=true" # try next drive if one is full during a write
            "minfreespace=30G"
            # the main disk is mandatory: without it there's no pool (and no services that need it),
            # instead of an empty pool that jellyfin/plex/arrs would happily scan
            "x-systemd.requires=mnt-media-16TB.mount"
            "x-systemd.after=mnt-media-16TBb.mount" # optional disk: order only
            "x-systemd.mount-timeout=20s"
        ];
    };

    # (re)mount on plug-in, like the automount used to (also after a USB dropout)
    services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="aead249c-8fbf-44f1-b9d5-a80c6dd3c160", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-mediapool-mainet.mount"
        ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="05525013-c780-4fb2-ac6d-8839cf01bcc8", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-media-16TBb.mount"
    '';
}
