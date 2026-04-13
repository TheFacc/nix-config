# MPV media player
#TODO personalize
# { pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    bindings = { # $XDG_CONFIG_HOME/mpv/input.conf
      WHEEL_UP = "add volume 2";
      WHEEL_DOWN = "add volume -2";
      WHEEL_LEFT = "seek -10"; # seek 10 seconds backward
      WHEEL_RIGHT = "seek 10";  # seek 10 seconds forward
      "Alt+0" = "set window-scale 0.5";
      "Alt+KP1" = "add video-rotate -30"; # rotate video counterclockwise by 30 degrees
      "Alt+KP5" = "set video-rotate  0"; # reset rotation
      "Alt+KP3" = "add video-rotate  30"; # rotate video clockwise by 30 degrees
    };
    # config = { # $XDG_CONFIG_HOME/mpv/mpv.conf
    #   profile = "gpu-hq";
    #   force-window = true;
    #   ytdl-format = "bestvideo+bestaudio";
    #   cache-default = 4000000;
    # }
  };
}
