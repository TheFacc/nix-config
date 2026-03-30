*So anyways. Here's my dots. I hope you like them.*

# My NixOS Flake Configuration

Welcome! This repository contains my personal NixOS configuration, built using flakes and inspired by [EmergentMind's nix-config](https://github.com/EmergentMind/nix-config). It is a highly modular, reproducible, and scalable way to manage multiple NixOS systems and user environments, with a single, text-based configuration.

- **Reproducibility:** Every system and user environment is described as code, so you can rebuild or roll back at any time.
- **Modularity:** Hosts and home environments are separated, but mirror each other for clarity and maintainability.
- **Scalability:** Easily add new machines, users, or features without spaghetti.

This structure makes it easy to understand what's happening where, and how to extend it for your own needs.
I can rebuild my whole digital life in minutes, anywhere, with a single command.
I'm dedicated to maintainable, scalable, and modular practices.
People be like "Uhmm aight, but... Why?!". Idk I guess I like rabbit holes. Deep, dark, and painful. But declarative.
Now I don't fear nuking my system and starting over.


## 🧩 Repo Structure
```
.
├── flake.nix          # Entry point: ties everything together
├── hosts/             # System configs (per-machine)
│   ├── common/        # Shared system modules
│   │   ├── core/      # System-level settings for all hosts (locale, DNS, shell, sops secrets, etc.)
│   │   ├── optional/  # Optional system modules (WM, apps, services, etc.)    <-- the juice
│   │   └── users/     # Global user settings (groups, home-manager refs)
│   └── $hostname/     # Host-specific system configs    <-- imports the above
│
├── home/                    # Home-manager configs (per-user)
│   ├── common/              # Shared user modules across all users
│   │   ├── core/            # User-level settings always present for ALL users
│   │   └── optional/        # Optional user modules
│   └── $username/           # User-specific home configs for each system (apps, etc.)
│         ├── common/        # Shared user modules
│         │   ├── core/      # User-level settings always present for THIS user (env, git, etc.)
│         │   └── optional/  # Optional user modules (browsers, vscode, etc.)
│         └── $hostname      # Host-specific home configs    <-- imports the above
│
├── modules/          # (Future) Custom modules for NixOS/home-manager
├── overlays/         # (Future) Custom package overlays
├── pkgs/             # (Future) Custom packages
├── still_to_flake/   # Legacy or WIP configs not yet flake-ified
└── ...
```


### How does it work?
- **`flake.nix`** imports and connects everything. It defines the inputs (Nixpkgs, home-manager, etc.) and outputs (system and home-manager configs for each host/user).
- **`hosts/`** contains all system-level configs. Each host (machine) has its own directory, plus a `common/` folder for shared modules (like localization, SSH, or secrets management).
- **`home/`** contains user-level (dotfiles) configs, managed by home-manager. Each user has a folder, and inside, a config for each host they log into. There's also a `common/` folder for settings shared across all hosts for a user.
- **`modules/`, `overlays/`, `pkgs/`** are placeholders for custom modules, overlays, and packages. They're ready for future expansion, so you can easily add your own tweaks without breaking the core structure.
- **`still_to_flake/`** contains legacy or experimental configs that haven't been fully migrated to the flake structure yet.



## 🏗️ Core Idea & Philosophy
- **Mirror Structure:** Both `hosts/` and `home/` use a similar layout, making it intuitive to see which configs apply system-wide vs. per-user.
- **Separation of Concerns:** System configs (NixOS modules) and user configs (home-manager) are kept distinct, but are easy to cross-reference.
- **Easy to Extend:** Want to add a new machine? Just add a `hosts/$hostname/` folder with the usual imports and hardware, create its users by adding a `home/$username/$hostname.nix` file, and finally import both in `flake.nix`. New user? Just add a `home/$username/` folder.
- **Future-Proof:** The modular design means you can grow this setup with overlays, custom modules, or new Nix features as they become relevant.



## 🛠️ Getting Started
If you bumped your head and forgot how to use this, here's a quick refresher:

1. **Clone this repo:**
   ```sh
   git clone https://github.com/TheFacc/nix-config.git
   cd nix-config
   ```
2. **Review the structure:**
   - Edit or add your host in `hosts/`
   - Edit or add your user in `home/`
3. **Build or switch:**
   ```sh
   # For system (as root)
   nixos-rebuild switch --flake .#your-hostname

   # For user environment (as user)
   home-manager switch --flake .#your-username@your-hostname
   ```
4. **Tweak, expand, and enjoy!**

### Secrets (sops-nix)

Sensitive values (e.g. Syncthing GUI password, credentials, etc.) are **not** stored in the Nix store as plaintext. This flake uses **[sops-nix](https://github.com/Mic92/sops-nix)** with **[SOPS](https://github.com/getsops/sops)** and **age**:

- **In git:** encrypted `hosts/common/core/secrets/secrets.yaml` (ciphertext), `.sops.yaml` (age **public** recipients only), and `secrets.yaml.example` (placeholders).
- **On each machine:** private age key at `/var/lib/sops-nix/keys.txt` (created manually or by tooling - see the doc below).
- **At runtime:** decrypted material under `/run/secrets` (and rendered templates), not world-readable store paths.

**If you clone this repo:** you cannot rebuild the same secrets without your **own** age keys and a new encrypted `secrets.yaml`. Short flow:

1. Install `age` and `sops` (`nix shell nixpkgs#age nixpkgs#sops`).
2. Generate keys and fill `hosts/common/core/secrets/.sops.yaml` with your **public** age keys.
3. Copy `secrets.yaml.example` → `secrets.yaml`, edit values, then encrypt with `sops` (nested YAML shape must match the example - see the doc).
4. Put the matching **private** key on each host as `/var/lib/sops-nix/keys.txt`, then `sudo nixos-rebuild switch --flake .#hostname`.

Full step-by-step notes, troubleshooting, and what is safe to publish are in **[`hosts/common/core/secrets/README.md`](hosts/common/core/secrets/README.md)**.



## 📚 References & Inspiration
- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config)
- [Anatomy doc I'm based on (commit 14adb98)](https://github.com/EmergentMind/nix-config/blob/14adb9899cb101d0599dc3d7aa88a70ba4cf0388/docs/anatomy.md)
- [NixOS](https://nixos.org/)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Nix flakes](https://nixos.wiki/wiki/Flakes)

---

*Feel free to fork, adapt, or reach out if you have questions or want to collaborate!*
