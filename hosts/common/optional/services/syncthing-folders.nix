{ config, lib, ... }:

# TODO inherit user?
# TODO merge with syncthing-devices.nix using secrets

let
  user = "facc";
  # sync
  st_obsidian = {
      id = "obsidian-main";
      label = "(sync) obsidian";
      type = "sendreceive";
      devices = [ "nixossone" "Ultracc" ];
  };
  st_walls = {
      id = "walls-all";
      label = "(sync) walls-all";
      type = "sendreceive";
      devices = [ "nixex" "nixossone" ];
  };
  st_walls_cell = {
      id = "walls-cell";
      label = "(sync) walls-cell";
      type = "sendreceive";
      devices = [ "nixex" "nixossone" "Ultracc" ];
  };
  st_backups = {
      id = "backuparr";
      label = "(sync) backuparr";
      type = "sendreceive";
      devices = [ "nixex" "nixossone" ];
  };
  # one way
  st_toPixel1 = {
      id = "toPixel1";
      label = "(sync) toPixel1";
      type = "sendonly";
      devices = [ "Pixel1" ];
  };
in
{

    services.syncthing = {
      enable = true;
      user = "${user}";
      dataDir = "/home/${user}";
      settings.folders = lib.mkMerge [
        # nixossone:
        (lib.mkIf (config.networking.hostName == "nixossone") {
          # Obsidian
          "/home/${user}/Documents/Obsidian/" = st_obsidian;
          # walls
          "/home/${user}/Pictures/walls" = st_walls;
          "/home/${user}/Pictures/walls/CellWallCopiesSync" = st_walls_cell;
          # backups
          "/home/${user}/Documents/_backuparr" = st_backups;
          # toPixel1
          "/home/${user}/Pictures/_toPixel1" = st_toPixel1;
        })

        # nixex:
        (lib.mkIf (config.networking.hostName == "nixex") {
          # walls
          "/mnt/ssd512/Pictures/walls" = st_walls;
          "/mnt/ssd512/Pictures/walls/CellWallCopiesSync" = st_walls_cell;
          # backups
          "/var/lib/plex/mount/DJ/backups/" = st_backups;
        })
      ];
    };
}
