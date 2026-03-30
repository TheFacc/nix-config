# Secrets (SOPS + sops-nix)

This folder holds **encrypted** secrets and SOPS configuration. You run the steps below on your own machines; private keys stay on disk, not in git.

**Safe to publish in git:** this README, `secrets.yaml.example` (placeholders only), `.sops.yaml` (**age public keys only**—still semi-sensitive metadata about which machines exist), and `secrets.yaml` **after encryption** (ciphertext only).

**Never commit:** plaintext `secrets.yaml` with real values, `AGE-SECRET-KEY-…` private keys, or copies of `/var/lib/sops-nix/keys.txt`.

---

## 1. Install tools (one-off)

```sh
nix shell nixpkgs#age nixpkgs#sops
```

## 2. Age keys (pick an approach)

### A) Key on each NixOS host (manual, reliable)

sops-nix only runs its built-in `generate-age-key` when `sops.secrets` is non-empty, so you will **not** get a host key from a rebuild that defines zero secrets.

On each host:

```sh
nix shell nixpkgs#age -c sh -c 'sudo mkdir -p /var/lib/sops-nix && sudo age-keygen -o /var/lib/sops-nix/keys.txt && sudo chmod 600 /var/lib/sops-nix/keys.txt'
sudo grep '^age1' /var/lib/sops-nix/keys.txt
```

Put that **`age1…` public line** into [`.sops.yaml`](./.sops.yaml) (replace placeholders). Keep the private key file only on the host.

### B) Laptop-first

On the machine where you edit the repo:

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/nixos-sops.key.txt
```

`age-keygen` prints `Public key: age1…`. Add that string to `.sops.yaml` for each recipient entry (one shared key is fine to start; add per-host keys later with `sops updatekeys`).

Create and encrypt secrets:

```sh
cd hosts/common/core/secrets
cp secrets.yaml.example secrets.yaml
$EDITOR secrets.yaml
sops -e -i secrets.yaml
```

Placeholders in `.sops.yaml` must be real `age1…` keys before encrypting works.

Install the **private** key on each NixOS host (same file if you used one key):

```sh
sudo mkdir -p /var/lib/sops-nix
sudo install -m 600 -o root -g root /path/to/nixos-sops.key.txt /var/lib/sops-nix/keys.txt
```

Example over SSH:

```sh
scp ~/.config/sops/age/nixos-sops.key.txt USER@HOST:/tmp/sops.key
ssh USER@HOST 'sudo mkdir -p /var/lib/sops-nix && sudo install -m 600 -o root -g root /tmp/sops.key /var/lib/sops-nix/keys.txt && rm -f /tmp/sops.key'
```

Then `nixos-rebuild` with `secrets.yaml` tracked in git (or `--impure` while it is untracked).

## 3. Edit `.sops.yaml`

Replace `age1…` placeholders with real **public** keys for every host that must decrypt `secrets.yaml`.

## 4. Create the encrypted `secrets.yaml`

```sh
cd hosts/common/core/secrets
cp secrets.yaml.example secrets.yaml
# edit plaintext values (only briefly on disk)
sops secrets.yaml
```

SOPS encrypts using recipients from `.sops.yaml`.

## 5. Git

Commit **only** the encrypted `secrets.yaml`. Do not commit plaintext real passwords. If you ever put real values in `secrets.yaml.example`, strip them before pushing.

## 6. Rebuild

```sh
sudo nixos-rebuild switch --flake /path/to/flake#your-host
```

If `secrets.yaml` is gitignored and not tracked, you may need `--impure` until you add the ciphertext to git.

## 7. Rotating after losing keys

- Create a new `secrets.yaml` from `secrets.yaml.example`, re-encrypt with a fresh `.sops.yaml`.
- Deploy new `/var/lib/sops-nix/keys.txt` on each host and update `.sops.yaml` pubkeys to match.

---

## Editing / decrypting later (“cannot find data required to decrypt”)

- **Encrypt** (`sops -e -i`) only needs **public** keys from `.sops.yaml`.
- **Open** (`sops secrets.yaml`) **decrypts** first; SOPS must find a **private** key for one of the file’s recipients. It does **not** use `/var/lib/sops-nix/keys.txt` unless you point to it.

On a NixOS host (approach A.):

```sh
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt \
  sops hosts/common/core/secrets/secrets.yaml
```

On a laptop (approach B., after copying a host key or using a dedicated editor key):

```sh
export SOPS_AGE_KEY_FILE=/path/to/keys.txt
sops hosts/common/core/secrets/secrets.yaml
```

Or default location:

```sh
mkdir -p ~/.config/sops/age
cp /path/to/keys.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

**Optional:** add a third age key only on your laptop, put its public key in `.sops.yaml`, then from a machine that can already decrypt run `sops updatekeys secrets.yaml` so you can edit without copying host keys.

**Per-machine keys:** different keys on each host are fine; list **all** relevant public keys under `creation_rules` in `.sops.yaml` so the same `secrets.yaml` decrypts on each host with its own `keys.txt`.

---

## YAML shape (important)

Secret names in `*.nix` use slashes (e.g. `services/syncthing/gui_password`). sops-nix resolves them as **nested** YAML:

```yaml
services:
  syncthing:
    gui_password: "…"
```

Do **not** use a single top-level key named `services/syncthing/gui_password:`. See [`secrets.yaml.example`](./secrets.yaml.example).

If activation fails with `the key 'services' cannot be found`, decrypt with `sops`, fix structure to match the example, save, rebuild.

---

## Notes

- Plain secrets must not live in `*.nix`; they exist in encrypted YAML and under `/run/secrets` at runtime.
- Syncthing uses `guiPasswordFile`: the secret file is **plaintext**; NixOS hashes it with bcrypt when applying settings.
