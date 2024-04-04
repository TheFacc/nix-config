# MPV media player
#TODO personalize
# { pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    bindings = { # $XDG_CONFIG_HOME/mpv/input.conf
      WHEEL_UP = "seek 10";
      WHEEL_DOWN = "seek -10";
      "Alt+0" = "set window-scale 0.5";
    };
    # config = { # $XDG_CONFIG_HOME/mpv/mpv.conf
    #   profile = "gpu-hq";
    #   force-window = true;
    #   ytdl-format = "bestvideo+bestaudio";
    #   cache-default = 4000000;
    # }
  };
}
