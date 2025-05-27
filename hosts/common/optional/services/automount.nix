{
  fileSystems."/mnt/4TB" = {
    device = "/dev/disk/by-uuid/C4E8AEC1E8AEB15A";
    fsType = "ntfs-3g";
    options = ["uid=1000,forceuid,x-systemd.automount,x-systemd.mount-timeout=10s"];
  };
  fileSystems."/mnt/5TB" = {
    device = "/dev/disk/by-uuid/B4D2F66BD2F630EA";
    fsType = "ntfs-3g";
    options = ["uid=1000,forceuid,x-systemd.automount,x-systemd.mount-timeout=10s"];
  };
  fileSystems."/mnt/16TB" = {
    device = "/dev/disk/by-uuid/0074-AF7A";
    fsType = "exfat";
    options = ["uid=1000,forceuid,x-systemd.automount,x-systemd.mount-timeout=10s"];
  };
}