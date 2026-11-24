# nixex: move to the ex-nixook laptop

Runbook for install day. The old nixex stays untouched until the new one is verified (rollback, step 7).
Do not merge this branch into `flakes` before step 8: the old hardware can't boot this config.

Placeholders: `<new-ts-name>` is the name Tailscale gives the new box before cutover (e.g. `nixex-1`).
Device paths are examples (`/dev/nvme0n1`, `p1` ESP, `p2` LUKS): check with `lsblk` and adapt.

## 1. Before

BIOS (F2 on the laptop):
- TPM on (Intel PTT / "TPM device").
- Secure Boot on, in Setup Mode: delete/reset the platform key (PK) only. Don't pick
  "clear all Secure Boot keys" if it also drops dbx.
- Storage in AHCI mode, not RAID/RST/VMD, if the NVMe doesn't show up in the installer.

On a USB stick (wipe it afterwards), from a machine that has them:
- `/var/lib/sops-nix/keys.txt` (shared age key)
- `hosts/common/optional/services/syncthing-devices.json` (gitignored)

Nothing else to stage: rclone configs come with the state copy (`/var/lib/vaultsync`, `~/.config/rclone`),
the old box has no SSH host keys (Tailscale SSH only) and sops reads the age key, not SSH keys.

## 2. Install

Use Ethernet if you can: it comes up by itself on the installed system, Wi-Fi has to be set up again
after install. Boot the NixOS installer, get online, then:

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

Units that must not run on both boxes at once (one Telegram poller per bot token, Syncthing,
vault pushes). Saved in facc's home so later steps load it with `. ~/nixex-units.sh` (bash or zsh);
timers and path units come first so nothing restarts a stopped service:

```sh
cat > /mnt/home/facc/nixex-units.sh <<'EOF'
units=(
  vaultsync.timer servermon-arr.timer vault-snapshot.timer vault-snapshot-offsite.timer
  cloudflare-archive.timer jellyfin-backup.timer
  vaultsync-on-change.path vault-save-request.path
  vaultsync-on-change vault-save-request vault-snapshot-requested
  vaultsync vaultsync-watch-hermes vault-snapshot vault-snapshot-offsite cloudflare-archive jellyfin-backup
  hermes-agent hermes-backend vault-history-web telegram-bot-api tg-c2c n8n caddy
  plex tautulli jellyfin sonarr sonarr-dupsvc radarr radarr-dupsvc prowlarr qBittorrent flaresolverr
  podman-tinyMediaManager syncthing servermon servermon-arr
)
EOF
```

```sh
nixos-install --flake 'path:.#nixex' --no-root-passwd
nixos-enter --root /mnt -c 'passwd facc'
chown -R 1000:100 /mnt/home/facc
reboot
```

First boot asks for the LUKS passphrase, then reboots by itself once or twice to set up Secure Boot (step 3).
Enter the passphrase again, log in as facc on the console, then:

```sh
sudo nmcli --ask device wifi connect '<ssid>'   # Wi-Fi only; prompts for the password
sudo tailscale up --ssh   # open the printed URL; the box joins as <new-ts-name>
. ~/nixex-units.sh && sudo systemctl stop "${units[@]}"
ip -br link               # update network.interfaces in services/servermon.nix if not enp3s0
```

Until cutover, re-run the stop line after every boot (steps 3 and 4 reboot). Nothing can clash with
the old box yet (the bot secrets only arrive with the copy in 5.4), but stopped services keep
servermon from sending alerts and keep empty Syncthing/Plex/Jellyfin instances from writing state.

## 3. Secure Boot and TPM unlock

lanzaboote provisions Secure Boot by itself. The install boots unsigned; on first boot it generates
keys in `/var/lib/sbctl`, re-signs the ESP and reboots. On that boot systemd-boot enrolls the keys
(Microsoft's included), the firmware may reset once more, then the passphrase prompt comes back and
Secure Boot is enforcing.
`/var/lib/sbctl` lives on `@`: don't wipe it, or the box can't sign new generations.

Once it is back up:

```sh
bootctl status | grep 'Secure Boot'   # enabled (user)
sudo sbctl status                     # Installed, Setup Mode: Disabled, Secure Boot: Enabled
sudo sbctl verify                     # all files signed, except kernel-*.efi
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

Set up RustDesk first (end of this step, it needs the laptop's screen). Then close the lid and,
from another machine (zsh or bash):

```sh
h=facc@<new-ts-name>
before=$(ssh $h cat /proc/sys/kernel/random/boot_id)
ssh -t $h sudo reboot
# give it a couple of minutes: nobody types the passphrase, the TPM must unlock the disk
after=$(ssh $h cat /proc/sys/kernel/random/boot_id)   # empty = not reachable yet: wait, retry
[ -n "$before" ] && [ -n "$after" ] && [ "$after" != "$before" ] && echo REBOOTED
ssh $h systemctl is-system-running   # running; degraded means: systemctl --failed
ssh -t $h '. ~/nixex-units.sh && sudo systemctl stop "${units[@]}"'
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
. ~/nixex-units.sh
ssh root@nixex-old systemctl stop "${units[@]}" display-manager
sudo systemctl stop "${units[@]}"
ssh root@nixex-old systemctl is-active "${units[@]}" | grep -vxE 'inactive|failed'   # must print nothing
```

The array expands locally, so both boxes get the same list. `root@` goes through Tailscale SSH;
the default tailnet policy allows it, but the first connection prints a check URL: open it and
approve, then the command runs. Units the old box lacks only print an error.

3. Check that both boxes give the same numbers to the same names. State is copied with
   `--numeric-ids`, so a mismatch hands files to the wrong account:

```sh
diff <(ssh root@nixex-old getent passwd | cut -d: -f1,3 | sort) <(getent passwd | cut -d: -f1,3 | sort)
diff <(ssh root@nixex-old getent group | cut -d: -f1,3 | sort) <(getent group | cut -d: -f1,3 | sort)
```

   Fine: accounts that own nothing copied, such as sddm on the old box, lightdm on the new one,
   wpa_supplicant, geoclue, fwupd-refresh, systemd-oom, nscd, podman, resolvconf.
   Blocker: a different number for facc, media, plex, caddy, sonarr, radarr, syncthing or any
   account pinned in `hosts/nixex/default.nix`. Pin the old number there (5.8 commits it).
   NixOS won't change the ID of an account that already exists, so also change it by hand and
   hand over what the new number already owns:

```sh
sudo usermod -u <old-uid> <user>      # or: sudo groupmod -g <old-gid> <group>
sudo find / -xdev -uid <new-uid> -exec chown -h <old-uid> {} +   # -gid / chgrp for a group
sudo nixos-rebuild switch --flake 'path:/home/facc/dotfiles/nix-config#nixex'
```

   Then re-run the stop line and this check.

4. Copy state, as root on the new box. n8n and prowlarr use DynamicUser, so their data is under `/var/lib/private`.
   `/var/lib/tailscale` is not copied: the new box keeps its own node and takes the name in 5.7.
   The copy stops at the first failure and ends with `COPY OK` only if everything went through.

```sh
sudo -i
install -d -m 0700 /var/lib/private
(
  for d in caddy hermes jellyfin obsidian-vault plex plexpy radarr sonarr servermon \
           telegram-bot-api telegram-bot-api-secrets vault-history vault-snapshot vaultsync \
           private/n8n private/prowlarr; do
    rsync -aHAX --numeric-ids --delete --mkpath "root@nixex-old:/var/lib/$d/" "/var/lib/$d/" \
      || { echo "FAILED: $d"; exit 1; }
  done
  # whole home (tmm-config, rclone, syncthing identity, gh, TgC2C...); keeps the new nix-config
  # checkout and this box's Home Manager profile
  rsync -aHAX --numeric-ids --exclude=.cache/ --exclude=dotfiles/nix-config/ \
    --exclude=.nix-profile --exclude=.local/state/nix/ --exclude=.local/state/home-manager/ \
    root@nixex-old:/home/facc/ /home/facc/ || { echo "FAILED: home"; exit 1; }
  # the copy brought links into the old box's /nix/store (git config among them): relink
  systemctl restart home-manager-facc || { echo "FAILED: home-manager"; exit 1; }
  echo "COPY OK"
)
exit   # back to facc
```

5. Power off the old box, only once 5.3 shows no blocker and 5.4 printed `COPY OK`.
   Otherwise fix the cause and re-run 5.4 (rsync only sends the difference).

```sh
ssh root@nixex-old poweroff
```

6. Move the disks: 16TB (USB), 16TBb, ssd512. The laptop has no 2.5" bay, so ssd512 goes into a
   USB enclosure and its by-id changes: in `services/servermon.nix` (smartd), replace its `ata-...`
   path with the `usb-...` one from `ls -l /dev/disk/by-id` and add `-d sat`.
7. Tailscale admin console: rename `<new-ts-name>` to `nixex` (untick auto-generate), disable its
   key expiry (otherwise it drops off the tailnet in 180 days, and there's no other way in), and
   give it any tags `nixex-old` has. The new box has its own SSH host keys, so on each machine that
   connected to the old one: `ssh-keygen -R nixex` (and the `nixex.<tailnet>.ts.net` name if used).
8. Commit the hardware config, any ID pins from 5.3 and the servermon fixes, then rebuild and reboot:

```sh
cd /home/facc/dotfiles/nix-config
git add hosts/nixex/hardware-configuration.nix hosts/nixex/default.nix hosts/common/optional/services/servermon.nix
git commit -m "chore(nixex): fill in the hardware config from install day"
git push
sudo nixos-rebuild boot --flake 'path:.#nixex' && sudo reboot
```

## 6. Verify

```sh
systemctl --failed                    # empty
systemctl list-timers                 # the 6 timers from step 2 are scheduled
for m in /mnt/media/16TB /mnt/media/16TBb /mnt/mediapool/mainet /mnt/ssd512; do
  findmnt "$m" >/dev/null || echo "MISSING $m"
done                                  # prints nothing
sudo find /var/lib /home/facc /mnt/ssd512 /mnt/media/16TB /mnt/media/16TBb -xdev \
  \( -nouser -o -nogroup \) -print | head   # empty: every copied file has a known owner
sudo systemctl start vaultsync.service vault-snapshot.service
journalctl -u vaultsync -u vault-snapshot -n 30
journalctl -u smartd -b | grep 'monitor" list'   # one line each: usb-Seagate..., ssd512's usb-..., nvme0
bootctl status | grep 'Secure Boot'
```

By hand:
- Plex and Jellyfin play a file.
- Sonarr, Radarr (and 4K), Prowlarr: no health errors, root folders on the pool.
- Syncthing (`ssh -L 8384:localhost:8384 nixex`, open localhost:8384): folders up to date.
- Hermes dashboard on `https://nixex.<tailnet>.ts.net:8443` loads; if caddy shows a cert error,
  `sudo systemctl restart caddy`.
- servermon sends its Telegram startup message.
- The headless check from step 4 against `facc@nixex`, disks attached (skip its stop line).

## 7. Rollback

The old box and its system disk are unchanged.

1. Power off the new box, move the disks back.
2. Tailscale admin console: rename the new box (e.g. `nixex-new`) and `nixex-old` back to `nixex`.
3. Boot the old box. Its state is as of the cutover: anything changed on the new box since is not there.

Boot its existing generation and don't rebuild it: this branch, and `flakes` once merged, only fit the new laptop.

## 8. Merge

Once the new box has run cleanly for a while, mark the PR ready and merge it into `flakes`.
