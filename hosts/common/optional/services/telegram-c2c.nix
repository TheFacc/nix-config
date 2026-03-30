{ config, pkgs, ... }:
let
  user = "facc";
  wd = "/home/${user}/Documents/TgC2C";
  c2c-python-packages = python-packages: with python-packages; [
  #  python-telegram-bot
    telethon
  ];
  python-c2c = pkgs.python313.withPackages c2c-python-packages;
in
{
 # environment.systemPackages = [ pkgs.python3 ];

  systemd.services.tg-c2c = {
    description = "Telegram C2C Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
#    path = [ python-c2c pkgs.bash pkgs.coreutils ];  # date command

    script = ''
      # Ensure directory exists and is accessible
      mkdir -p ${wd}
      cd ${wd} || exit 1
      
      # Run with your exact logging
      exec ${python-c2c}/bin/python3 Telegram_C2C.py #> log.$(date +%Y-%m-%d_%H-%M).out 2>&1 &
    '';

    serviceConfig = {
      Type = "simple";
      User = user;
      Group = "users";
      WorkingDirectory = wd;
      Restart = "always";
      RestartSec = 10;
    };
  };
}
