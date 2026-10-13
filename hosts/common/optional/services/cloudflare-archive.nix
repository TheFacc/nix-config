# cloudflare-archive: daily copy of Cloudflare's per-request analytics (tvtime-archive.com, commsuni.tv)
# module: modules/nixos/cloudflare-archive
#
# Secret (add it with `sops secrets.yaml` BEFORE deploying; sops-nix fails activation on missing keys):
#   services/cloudflare_archive/api_token   Cloudflare API token, "Read analytics and logs" template
#                                           or custom: Zone > Analytics > Read on both zones
{ config, lib, ... }:
lib.mkIf config.local.hasSopsSecrets {
  services.cloudflare-archive = {
    enable = true;
    tokenFile = config.sops.secrets."services/cloudflare_archive/api_token".path;
    # big pool next to the other backups; / on nixex is small
    dataDir = "/mnt/mediapool/mainet/_bk/cloudflare-archive";
    zones = [
      { name = "tvtime-archive.com"; id = "28066fc141cfbe3cae4317164b8b1eef"; }
      { name = "commsuni.tv"; id = "2ee8ab185f45ee783265fa6b1eab0d8c"; }
    ];
  };

  # read by systemd (LoadCredential) as root, never by the service user directly
  sops.secrets."services/cloudflare_archive/api_token".mode = "0400";
}
