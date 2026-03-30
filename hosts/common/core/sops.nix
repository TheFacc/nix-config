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
      };

      templates."git-user-thefacc-email" = {
        owner = config.users.users.facc.name;
        mode = "0600";
        content = ''
          [user "TheFacc"]
            email = ${config.sops.placeholder."users/facc/git/email"}
        '';
      };
    })
  ];

  warnings = lib.mkIf (!config.local.hasSopsSecrets) [
    "hosts/common/core/secrets/secrets.yaml is missing: create it from secrets.yaml.example, encrypt with sops, and add it to git (ciphertext only). See hosts/common/core/secrets/README.md."
  ];
}
