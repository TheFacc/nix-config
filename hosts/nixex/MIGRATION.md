# nixex: move to the ex-nixook laptop

Runbook for install day. The old nixex stays untouched until the new one is verified (rollback, step 7).
Do not merge this branch into `flakes` before step 8: the old hardware can't boot this config.

Placeholders: `<new-ts-name>` is the name Tailscale gives the new box before cutover (e.g. `nixex-1`).
Device paths are examples (`/dev/nvme0n1`, `p1` ESP, `p2` LUKS): check with `lsblk` and adapt.

## 1. Before

BIOS (F2 on the laptop):
- TPM on (Intel PTT / "TPM device").
- Secure Boot **off** for now.
- Storage in AHCI mode, not RAID/RST/VMD, if the NVMe doesn't show up in the installer.

On a USB stick (wipe it afterwards), from a machine that has them:
- `/var/lib/sops-nix/keys.txt` (shared age key)
- `hosts/common/optional/services/syncthing-devices.json` (gitignored)

Nothing else to stage: rclone configs come with the state copy (`/var/lib/vaultsync`, `~/.config/rclone`),
the old box has no SSH host keys (Tailscale SSH only) and sops reads the age key, not SSH keys.

## 2. Install

Boot the NixOS installer, get online (Wi-Fi or Ethernet), then:

```sh
sudo -i
export NIX_CONFIG="experimental-features = nix-command flakes"
DISK=/dev/nvme0n1

parted -s $DISK -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB set 1 esp on \
  mkpart cryptroot 1GiB 100%
mkfs.fat -F32 -n BOOT ${DISK}p1
# The initrd prompt uses the US layout (console.keyMap is unset): type the passphrase with the
# installer's default US layout, not after `loadkeys it`
cryptsetup luksFormat --type luks2 ${DISK}p2
cryptsetup open ${DISK}p2 cryptroot

mkfs.btrfs -L nixex /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
for s in @ @home @nix @log; do btrfs subvolume create /mnt/$s; done
umount /mnt

o=compress=zstd,noatime
mount -o subvol=@,$o /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o subvol=@home,$o /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,$o /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,$o /dev/mapper/cryptroot /mnt/var/log
mount -o fmask=0077,dmask=0077 ${DISK}p1 /mnt/boot
```

Repo, secrets and hardware config:

```sh
git clone -b feat/nixex-on-nixook https://github.com/TheFacc/nix-config /mnt/home/facc/dotfiles/nix-config
cd /mnt/home/facc/dotfiles/nix-config

mkdir -p /media/usb && mount /dev/sda1 /media/usb   # the USB stick, adapt
cp /media/usb/syncthing-devices.json hosts/common/optional/services/
install -D -m 600 /media/usb/keys.txt /mnt/var/lib/sops-nix/keys.txt

sed -i "s/REPLACE-ME-LUKS-PARTITION-UUID/$(blkid -s UUID -o value ${DISK}p2)/; \
        s/REPLACE-ME-ESP-UUID/$(blkid -s UUID -o value ${DISK}p1)/" hosts/nixex/hardware-configuration.nix
nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw-generated.nix
grep -i kernelmodules /tmp/hw-generated.nix hosts/nixex/hardware-configuration.nix
```

If the generated module lists differ (e.g. `thunderbolt`, `vmd`), copy them into
`hosts/nixex/hardware-configuration.nix`. Keep everything else in the template.

Secure Boot keys, created now so lanzaboote signs the boot files during install:

```sh
nix shell nixpkgs#sbctl -c sbctl create-keys
mkdir -p /mnt/var/lib && cp -a /var/lib/sbctl /mnt/var/lib/
```

If the install fails on missing keys, set `boot.lanzaboote.autoGenerateKeys.enable = true;` in
`hosts/nixex/default.nix` instead (keys are made on first boot, unsigned files allowed until then),
then remove it and rebuild once the keys exist.

```sh
nixos-install --flake 'path:.#nixex' --no-root-passwd
nixos-enter --root /mnt -c 'passwd facc'
chown -R 1000:100 /mnt/home/facc
reboot
```

First boot asks for the LUKS passphrase. Log in as facc on the console, then:

```sh
sudo tailscale up --ssh   # open the printed URL; the box joins as <new-ts-name>
ip -br link               # update network.interfaces in services/servermon.nix if not enp3s0
```

Expect Telegram errors (Hermes, tg-c2c, servermon) while both boxes run with the same bot tokens:
Telegram allows one poller per token. Keep the gap to cutover short.

## 3. Secure Boot and TPM unlock

```sh
sudo sbctl verify            # all files signed, except kernel-*.efi
sudo systemctl reboot --firmware-setup
```

In the BIOS: enable Secure Boot and put it in Setup Mode (delete/reset the platform key).
Don't pick "clear all Secure Boot keys" if it also drops dbx. Boot NixOS, then:

```sh
sudo sbctl status            # Setup Mode: Enabled
sudo sbctl enroll-keys --microsoft
sudo reboot
bootctl status | grep 'Secure Boot'   # enabled (user)
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2
sudo systemd-cryptenroll /dev/nvme0n1p2   # slots: password + tpm2
sudo reboot                  # no keyboard input: it must reach the login prompt by itself
```

Recovery: the passphrase always works at the prompt. A firmware update or a Secure Boot key change
alters PCR 7 and makes the TPM refuse; after booting with the passphrase, re-enroll:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2
```

## 4. Headless check and desktop on demand

Close the lid, then from another machine:

```sh
ssh -t facc@<new-ts-name> sudo reboot
ssh facc@<new-ts-name> systemctl is-system-running
```

Desktop (LightDM logs facc into XFCE):

```sh
sudo systemctl start display-manager
sudo systemctl stop display-manager
```

RustDesk, once, on the laptop's own screen with the desktop running:
Settings > Security > enable "Direct IP access", set a permanent password.
Connect from another RustDesk to the box's Tailscale name or IP.

## 5. Cutover

1. Tailscale admin console: rename the old machine `nixex` to `nixex-old`.
2. Stop everything on both boxes, from the new one:

```sh
UNITS="vaultsync.timer servermon-arr.timer vault-snapshot.timer vault-snapshot-offsite.timer \
  cloudflare-archive.timer jellyfin-backup.timer \
  vaultsync vaultsync-watch-hermes vault-snapshot vault-snapshot-offsite cloudflare-archive jellyfin-backup \
  hermes-agent hermes-backend vault-history-web telegram-bot-api tg-c2c n8n caddy \
  plex tautulli jellyfin sonarr sonarr-dupsvc radarr radarr-dupsvc prowlarr qBittorrent flaresolverr \
  podman-tinyMediaManager syncthing servermon servermon-arr"
ssh root@nixex-old "systemctl stop $UNITS display-manager"
sudo systemctl stop $UNITS
```

`root@` goes through Tailscale SSH; the default tailnet policy allows it. Units that don't exist only print an error.

3. Copy state, as root on the new box. n8n and prowlarr use DynamicUser, so their data is under `/var/lib/private`.
   `/var/lib/tailscale` is not copied: the new box keeps its own node and takes the name in step 5.

```sh
sudo -i
install -d -m 0700 /var/lib/private
for d in caddy hermes jellyfin obsidian-vault plex plexpy radarr sonarr servermon \
         telegram-bot-api telegram-bot-api-secrets vault-history vault-snapshot vaultsync containers \
         private/n8n private/prowlarr; do
  rsync -aHAX --numeric-ids --delete --mkpath "root@nixex-old:/var/lib/$d/" "/var/lib/$d/"
done
# whole home (tmm-config, rclone, syncthing identity, gh, TgC2C...); keeps the new nix-config checkout
rsync -aHAX --numeric-ids --exclude=.cache/ --exclude=dotfiles/nix-config/ \
  root@nixex-old:/home/facc/ /home/facc/
ssh root@nixex-old poweroff
```

4. Move the disks: 16TB (USB), 16TBb, ssd512. If ssd512 goes into a USB enclosure, put its
   `/dev/disk/by-id/usb-...` path in `services/servermon.nix` (smartd) and add `-d sat`.
5. Tailscale admin console: rename `<new-ts-name>` to `nixex` (untick auto-generate).
6. Commit the hardware config and any servermon fixes, then rebuild and reboot:

```sh
cd ~/dotfiles/nix-config
git add hosts/nixex/hardware-configuration.nix hosts/common/optional/services/servermon.nix
git commit -m "chore(nixex): fill in the hardware config from install day"
git push
sudo nixos-rebuild boot --flake 'path:.#nixex'
sudo reboot
```

## 6. Verify

```sh
systemctl --failed                    # empty
systemctl list-timers                 # the 6 timers from step 5 are scheduled
findmnt /mnt/media/16TB /mnt/media/16TBb /mnt/mediapool/mainet /mnt/ssd512
id facc                               # uid 1000, media(993)
for u in jellyfin prowlarr n8n hermes servermon vaultsync vault-history-web cloudflare-archive; do id $u; done
# expect 994 993 988 985 986 987 984 983, as in hosts/nixex/default.nix
sudo systemctl start vaultsync.service vault-snapshot.service
journalctl -u vaultsync -u vault-snapshot -n 30
journalctl -u smartd -b | grep -i -e nvme -e Seagate -e ssd512 -e Fanxiang
bootctl status | grep 'Secure Boot'
```

By hand:
- Plex and Jellyfin play a file.
- Sonarr, Radarr (and 4K), Prowlarr: no health errors, root folders on the pool.
- Syncthing (`ssh -L 8384:localhost:8384 nixex`, open localhost:8384): folders up to date.
- Hermes dashboard on `https://nixex.<tailnet>.ts.net:8443` loads; if caddy shows a cert error,
  `sudo systemctl restart caddy`.
- servermon sends its Telegram startup message.

## 7. Rollback

The old box and its system disk are unchanged.

1. Power off the new box, move the disks back.
2. Tailscale admin console: rename the new box (e.g. `nixex-new`) and `nixex-old` back to `nixex`.
3. Boot the old box. Its state is as of the cutover: anything changed on the new box since is not there.

Don't rebuild the old box from this branch or from `flakes` after step 8. Boot its existing generation.

## 8. Merge

Once the new box has run cleanly for a while, mark the PR ready and merge it into `flakes`.
