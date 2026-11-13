{ inputs, config, lib, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Single `sops` attr (Nix errors if you mix `sops.age` and `sops =` in one set).
  # generateKey runs only when sops.secrets is non-empty (sops-nix); see secrets/README.md.
  sops = lib.mkMerge [
    {
      age = {
        keyFile = "/var/lib/sops-nix/keys.txt";
        generateKey = true;
      };
    }
    (lib.mkIf config.local.hasSopsSecrets {
      defaultSopsFile = ./secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      validateSopsFiles = false;
      secrets = {
        "services/syncthing/gui_password" = {
          owner = config.users.users.facc.name;
          mode = "0400";
          restartUnits = [ "syncthing.service" ];
        };
        # Decrypted on the system (root); template is owned by facc for git include.
        "users/facc/git/email" = {
          owner = config.users.users.facc.name;
          mode = "0400";
        };
        "users/facc/git/work_email" = {
          owner = config.users.users.facc.name;
          mode = "0400";
        };
        # GitHub token for flake fetches: lifts the anonymous 60 req/h limit.
        "users/facc/github/nix_token" = { };
      };

      # facc-owned: `nix flake update` fetches in the client, not the daemon.
      templates."nix-access-tokens" = {
        owner = config.users.users.facc.name;
        mode = "0400";
        content = ''
          access-tokens = github.com=${config.sops.placeholder."users/facc/github/nix_token"}
        '';
      };

      templates."git-user-thefacc-email" = {
        owner = config.users.users.facc.name;
        mode = "0600";
        content = ''
          [user]
            email = ${config.sops.placeholder."users/facc/git/email"}
        '';
      };

      templates."git-user-becq-email" = {
        owner = config.users.users.facc.name;
        mode = "0600";
        content = ''
          [user]
            email = ${config.sops.placeholder."users/facc/git/work_email"}
        '';
      };
    })
  ];

  # `!include` skips the file silently when missing or unreadable (other users).
  nix.extraOptions = lib.mkIf config.local.hasSopsSecrets ''
    !include ${config.sops.templates."nix-access-tokens".path}
  '';

  warnings = lib.mkIf (!config.local.hasSopsSecrets) [
    "hosts/common/core/secrets/secrets.yaml is missing: create it from secrets.yaml.example, encrypt with sops, and add it to git (ciphertext only). See hosts/common/core/secrets/README.md."
  ];
}
