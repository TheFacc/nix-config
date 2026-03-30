{ lib, ... }:
{
  options.local.hasSopsSecrets = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    default = builtins.pathExists ./secrets/secrets.yaml;
    description = ''
      True when hosts/common/core/secrets/secrets.yaml exists in the flake tree
      (tracked in git or present on disk with --impure). Used to avoid referencing
      a missing secrets file during evaluation.
    '';
  };
}
