{ pkgs, lib, config, ... }:

with lib;

let cfg = config.services.fusuma;
in {
  options.services.fusuma = {
    enable = mkEnableOption "Enable fusuma service";
    package = mkOption {
      type = types.package;
      default = pkgs.fusuma;
      defaultText = "pkgs.fusuma";
      description = "Set the version of fusuma";
    };
    configFile = mkOption {
      type = types.str;
      description = "Path for fusuma's configuration file";
      default = "~/.config/fusuma/config.yaml";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.fusuma = {
      description = "Start fusuma to handle swipe";
      wantedBy = [ "multi-user.target" ];
      after = [ "graphical-session.target" ];
      restartIfChanged = true;
      serviceConfig = {
        Restart = "always";
        DynamicUser = true;
        ExecStart = ''${cfg.package}/bin/fusuma --config=${cfg.configFile}'';
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ ];
}
