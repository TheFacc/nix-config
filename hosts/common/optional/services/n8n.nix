# n8n
{ pkgs, lib, ... }:
{
    services.n8n = {
        enable = true;
    };

    systemd.services.n8n.serviceConfig = {
      User = "n8n";
      Group = "n8n";
    };

    users.groups.n8n = {};
    users.users.n8n = {
      isSystemUser = true;
      group = "n8n";
    };

    # Community nodes
    # https://github.com/jhakonen/nixos-config/blob/71e3518c15bbb0e26029adb66363b93ae08b614b/modules/features/n8n.nix#L21
#    systemd.services.n8n.serviceConfig.ExecStartPre = pkgs.writeShellScript "n8n-pre-start.sh" ''
#      set -euo pipefail
#      mkdir -p "$N8N_USER_FOLDER"/.n8n/nodes
#      pushd "$N8N_USER_FOLDER"/.n8n/nodes
#        ${pkgs.nodejs}/bin/npm install -y ${lib.escapeShellArgs [
#        "n8n-nodes-elevenlabs"
#      ]}
#      popd
#    ''; # not working idk, building but no package, maybe v2 broken
    # workaround to make installation work in the UI
    # https://github.com/nixos/nixpkgs/issues/435198
    systemd.services.n8n.serviceConfig.ExecStart = lib.mkForce (
      lib.getExe (
        pkgs.writeShellApplication {
          name = "n8n";
          runtimeInputs = with pkgs; [
            nodejs
            gnutar
            gzip
          ];
          text = ''
            exec ${lib.getExe pkgs.n8n} "$@"
          '';
        }
      )
    );
}
