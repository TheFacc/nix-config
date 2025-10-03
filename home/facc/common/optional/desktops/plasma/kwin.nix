{ lib, ... }:
{
  programs.plasma.kwin = {

    effects = {
      desktopSwitching.animation = "slide";
      minimization.animation = "squash";
      shakeCursor.enable = true;
      windowOpenClose.animation = "fade";
      wobblyWindows.enable = true;
    };

    nightLight = {
      enable = true;
      mode = "times";
      temperature = {
#         day = 5000;
        night = 4000;
      };
      time = {
        evening = "21:30";
        morning = "06:00";
      };
      transitionTime = 90;
    };

    titlebarButtons = {
      left = [
        "more-window-actions"
        "on-all-desktops"
        "help"
      ];
      right = [
        "minimize"
        "maximize"
        "close"
      ];
    };

    virtualDesktops ={
      number = 3;
      rows = 2;
    };
  };

  # define activities
  programs.plasma.configFile = {
      "kactivitymanagerdrc"."activities"."f3110254-86b9-43b9-a637-a25d083ad1c2" = "1W";
      "kactivitymanagerdrc"."activities"."459b3f65-1e51-43b4-9e16-72ca74d58795" = "2P";
      "kactivitymanagerdrc"."activities-icons"."f3110254-86b9-43b9-a637-a25d083ad1c2" = "labplot";
      "kactivitymanagerdrc"."activities-icons"."459b3f65-1e51-43b4-9e16-72ca74d58795" = "usb-creator-kde";
      "kactivitymanagerdrc"."main"."currentActivity" = "f3110254-86b9-43b9-a637-a25d083ad1c2";
  };
}
