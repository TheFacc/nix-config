# servermon: Telegram alerts for nixex (media disks/mounts, services, SMART, power, network)
# module: modules/nixos/servermon
#
# Secrets (add them with `sops secrets.yaml` BEFORE deploying; sops-nix fails activation on missing keys):
#   services/servermon/bot_token   token from @BotFather
#   services/servermon/chat_id     your chat id (see hosts/common/core/secrets/secrets.yaml.example)
# Without secrets the monitor still runs and spools messages until a token shows up.
{ config, lib, ... }:
let
  inherit (config.networking) hostName;
  nixexSops = (hostName == "nixex" && config.local.hasSopsSecrets);
  sonarrDir = config.services.sonarr.dataDir;
  radarrDir = config.services.radarr.dataDir;
in
{
  services.servermon = {
    enable = true;

    telegram = lib.mkIf nixexSops {
      tokenFile = config.sops.secrets."services/servermon/bot_token".path;
      chatIdFile = config.sops.secrets."services/servermon/chat_id".path;
    };

    extraGroups = [ "systemd-journal" "media" ];

    # disks + mounts (see ../serverr/mediastorage.nix, hosts/nixex/hardware-configuration.nix)
    mounts = [
      { path = "/mnt/media/16TB"; uuid = "aead249c-8fbf-44f1-b9d5-a80c6dd3c160"; }
      # comes and goes (lives on another machine at times); the pool works without it
      { path = "/mnt/media/16TBb"; uuid = "05525013-c780-4fb2-ac6d-8839cf01bcc8"; required = false; }
      { path = "/mnt/mediapool/mainet"; } # mergerfs
      { path = "/mnt/ssd512"; uuid = "c8b71c18-9ce1-4b44-b3bc-2a9d97131045"; } # downloads
    ];
    diskSpace = [
      { path = "/"; warnFreePercent = 10; critFreePercent = 5; }
      { path = "/mnt/ssd512"; warnFreePercent = 10; critFreePercent = 5; minFreeGiB = 50; }
      { path = "/mnt/mediapool/mainet"; warnFreePercent = 5; critFreePercent = 2; minFreeGiB = 500; }
    ];

    network.interfaces = [ "enp3s0" ];
    power = { ac = "ADP1"; battery = "BAT1"; }; # /sys/class/power_supply on the Samsung

    # sonarr/radarr/... are picked up automatically when enabled
    failureAlerts.extraServices = [ "tg-c2c" "flaresolverr" ]
      ++ lib.optional (config.users.users ? vaultsync) "vaultsync" # obsidian vault bisync
      ++ lib.optional config.services.vault-snapshot.enable "vault-snapshot"
      ++ lib.optional (config.services.vault-snapshot.offsite.enable or false) "vault-snapshot-offsite";

    smartd = {
      enable = true;
      devices = [
        # USB bridge needs SAT passthrough; `removable` = don't die if it's unplugged at start
        { device = "/dev/disk/by-id/usb-Seagate_Expansion_HDD_00000000NT174VPM-0:0"; options = "-d removable -d sat"; }
        { device = "/dev/disk/by-id/ata-Fanxiang_S101_512GB_AA000000000000063100"; } # /mnt/ssd512
        { device = "/dev/disk/by-id/ata-KingDian_S280-120GB_2016052500037"; } # system
        # TODO 16TBb: add its /dev/disk/by-id/usb-... path once it's plugged in again
      ];
    };

    # "waiting to import" check; API keys are read from config.xml through LoadCredential
    arr = {
      enable = true;
      instances = [
        { name = "sonarr"; url = "http://127.0.0.1:8989"; apiKeyFile = "${sonarrDir}/config.xml"; }
        { name = "radarr"; url = "http://127.0.0.1:7878"; apiKeyFile = "${radarrDir}/config.xml"; }
        { name = "sonarr-4K"; url = "http://127.0.0.1:8984"; apiKeyFile = "${sonarrDir}-4K/config.xml"; }
        { name = "radarr-4K"; url = "http://127.0.0.1:7874"; apiKeyFile = "${radarrDir}-4K/config.xml"; }
      ];
    };
  };

  # - init secrets
  sops.secrets = lib.mkIf nixexSops {
    "services/servermon/bot_token" = {
      owner = config.services.servermon.user;
      mode = "0400";
    };
    "services/servermon/chat_id" = {
      owner = config.services.servermon.user;
      mode = "0400";
    };
  };
}
