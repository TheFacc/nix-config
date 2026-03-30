{ config, lib, ... }:

let
  user = "facc"; # TODO inherit user?

  stDeviceIds = builtins.fromJSON (builtins.readFile ./syncthing-devices.json); # map name:id
  stDevices = lib.mapAttrs (_name: id: {
    inherit id;
    compression = "never";
  }) stDeviceIds;

  # sync walls
  st_walls = {
    id = "walls-all";
    label = "(sync) walls-all";
    type = "sendreceive";
    devices = [ "nixex" "nixossone" "nixook" ];
  };
  st_walls_desktop = {
    id = "walls-desktop";
    label = "(sync) walls-desktop";
    type = "sendreceive";
    devices = [ "nixex" "nixossone" "nixook" ];
  };
  st_walls_cell = {
    id = "walls-cell";
    label = "(sync) walls-cell";
    type = "sendreceive";
    devices = [ "nixex" "nixossone" "nixook" "Ultracc" ];
  };
  # sync backups
  st_backuparr = {
    id = "backuparr";
    label = "(sync) backuparr";
    type = "sendreceive";
    devices = [ "nixex" "nixossone" "nixook" ];
  };

  # one-way
  st_toPixel1 = {
    id = "toPixel1";
    label = "(out) toPixel1";
    type = "sendonly";
    devices = [ "Pixel1" ];
  };

in
{
  assertions = [
    {
      assertion = !config.services.syncthing.enable || config.local.hasSopsSecrets;
      message = "Syncthing is enabled but hosts/common/core/secrets/secrets.yaml is missing; create and encrypt it (see hosts/common/core/secrets/README.md).";
    }
  ];

  services.syncthing = {
    enable = true;
    user = user;
    dataDir = "/home/${user}";
    guiPasswordFile = lib.mkIf config.local.hasSopsSecrets config.sops.secrets."services/syncthing/gui_password".path;
    settings = {
      devices = stDevices;
      folders = lib.mkMerge [
        # nixossone:
        (lib.mkIf (config.networking.hostName == "nixossone") {
          "/home/${user}/Pictures/walls" = st_walls;
          "/home/${user}/Pictures/walls/DesktopWallCopies" = st_walls_desktop;
          "/home/${user}/Pictures/walls/CellWallCopies" = st_walls_cell;
          "/home/${user}/Documents/_backuparr" = st_backuparr;
          "/home/${user}/Pictures/_toPixel1" = st_toPixel1;
        })
        # nixook:
        (lib.mkIf (config.networking.hostName == "nixook") {
          "/home/${user}/Pictures/walls" = st_walls;
          "/home/${user}/Pictures/walls/DesktopWallCopies" = st_walls_desktop;
          "/home/${user}/Pictures/walls/CellWallCopies" = st_walls_cell;
          "/home/${user}/Documents/_backuparr" = st_backuparr;
          "/home/${user}/Pictures/_toPixel1" = st_toPixel1;
        })
        # nixex:
        (lib.mkIf (config.networking.hostName == "nixex") {
          "/mnt/ssd512/Pictures/walls" = st_walls;
          "/mnt/ssd512/Pictures/walls/DesktopWallCopies" = st_walls_desktop;
          "/mnt/ssd512/Pictures/walls/CellWallCopies" = st_walls_cell;
          "/mnt/mediapool/mainet/_bk" = st_backuparr;
        })
      ];
    };
  };
}
