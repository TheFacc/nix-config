# Module to create a second network namespace, allowing to run services twice, wow!
# Make sure you configure them with different port and data dir if you want separate config)
# https://www.reddit.com/r/NixOS/comments/13ikbpc/running_a_second_instance_of_a_service_a_solution/

{ pkgs, lib, config, nixpkgs, ... }:

let
  baseSystem = nixpkgs.lib.nixosSystem {
    inherit (pkgs) system;
    modules = [
      ({ lib, ... }: {
        networking = {
          firewall.enable = false;
          useDHCP = false;
        };
        system = {
          inherit (config.system) stateVersion;
        };
      })
    ];
  };
  baseServices = builtins.concatLists (map builtins.attrNames baseSystem.options.systemd.services.definitions);
in {
  options.dupsvc = lib.mkOption {
    type = lib.types.attrs;
    default = {};
  };
  config = {
    systemd.services = lib.mkMerge (map
      (x: lib.mapAttrs' (name: value: {
        name = name + "-dupsvc";
        value = value // {
          serviceConfig = (if value?serviceConfig then value.serviceConfig else { }) // {
            # NetworkNamespacePath = "/var/run/netns/dupsvc"; ## namespace has no internet
          };
        };
      }) (builtins.removeAttrs x baseServices))
      (nixpkgs.lib.nixosSystem {
        inherit (pkgs) system;
        modules = [
          ({ ... }: {
            networking = {
              firewall.enable = lib.mkDefault false;
              useDHCP = lib.mkDefault false;
            };
            system = {
              inherit (config.system) stateVersion;
            };
          })
          ({ ... }: config.dupsvc)
        ];
      }).options.systemd.services.definitions);
  };
}