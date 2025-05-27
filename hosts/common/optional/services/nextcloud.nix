# help by https://d.moonfire.us/blog/2024/03/03/nixos-and-nextcloud/ -- skip: backup, redis, nginx/firewall
# https://nwright.tech/posts/nixos-nextcloud-setup/ - caddy, postgres
{ pkgs, config, ... }: # TODO all, nothing is actually in use here
# let
#     groupGid = "12343";
# in
{
  # # Set up the user in case you need consistent UIDs and GIDs. And also to make
  # # sure we can write out the secrets file with the proper permissions.
  users.groups.nextcloud = {
    gid = 12343;
  };
  users.users.nextcloud = {
    uid = 343;
    isSystemUser = true;
    group = "nextcloud";
    # extraGroups = [ config.users.groups.keys.name ]; # https://discourse.nixos.org/t/nixops-deploy-secrets-to-nextcloud/10414/2
  };

  sops.secrets = {
  #   # "passwords/nextcloud/root" = {
  #   #   owner = config.users.users.facc.name;
  #   #   inherit (config.users.users.facc) group;
  #   # };

    "nextcloud/adminpw" = {
      # sopsFile = ../../core/secrets/secrets.yaml; # use default
      mode = "0600";
      owner = "nextcloud";
      group = "nextcloud";
    };

  #   "nextcloud/dbpw" = {
  #     sopsFile = ../../core/secrets/secrets.yaml;
  #     mode = "0600";
  #     owner = "nextcloud";
  #     group = "nextcloud";
  #   };

  #   "nextcloud/secrets" = {
  #     sopsFile = ../../core/secrets/secrets.yaml;
  #     mode = "0600";
  #     owner = "nextcloud";
  #     group = "nextcloud";
  #   };
  };

  # environment.etc."nextcloud-admin-pass".text = "somenewpw2"; 
  # environment.etc."nextcloud-admin-pass".text = "$(cat ${config.sops.secrets."passwords/nextcloud/root".path})";
  services.nginx.virtualHosts."nextcloud".listen = [ { addr = "127.0.0.1"; port = 8444; } ]; # change port
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud30;  
    # configureRedis = true;
    hostName = "nextcloud";
    # secretFile = "/run/secrets/nextcloud/secrets"; ######## idk what should be inside this file

    # db
    # Let NixOS install and configure the database automatically.
    database.createLocally = true;
    
    # Increase the maximum file upload size to avoid problems uploading videos.
    maxUploadSize = "16G";

    config = {
      dbtype = "sqlite";
      # dbname = "nextcloud";
      # dbhost = "localhost";
      # dbpassFile = "/run/secrets/nextcloud/dbpw"; ###### 

      adminuser = "facc";
      adminpassFile = "/run/secrets/nextcloud/adminpw"; ######
      # adminpassFile = "/etc/nextcloud-admin-pass"; ###### 

      # trustedProxies = [ "localhost" "127.0.0.1" "YOUR_TAILSCALE_IP" "YOUR_DOMAIN" ];
      # extraTrustedDomains = [ "YOUR_DOMAIN" ];
      # overwriteProtocol = "https";
    };

    # # settings
    # settings = {
    #   maintenance_window_start = 2; # 02:00
    # };

    # # apps
    # extraAppsEnable = true;
    # extraApps = {
    #   inherit (config.services.nextcloud.package.packages.apps) contacts calendar;
    # };
  };
  # services.postgresql = {
  #   enable = true;
  #   ensureDatabases = [ "nextcloud" ];
  #   ensureUsers = [
  #     {
  #       name = "nextcloud";
  #       ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
  #     }
  #   ];
  # };
  # # ensure that postgres is running *before* running the setup
  # systemd.services."nextcloud-setup" = {
  #     requires = ["postgresql.service"];
  #     after = ["postgresql.service"];
  # };
  
  # # we mount with facc, so that you can also unmount from the GUI normally (altho it hangs somewhat, fix by stopping automount service)
  # # we own the disks with a new group, and add me&nc users to that group
  # # disks - find UUID with `lsblk -f`
  # # permissions
  # users.users.facc = { # Nextcloud user https://discourse.nixos.org/t/get-linux-username-of-nixos-nextcloud-service/32337
  #   extraGroups = [ "nextcloud" ];
  # };
}

