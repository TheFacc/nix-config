{ pkgs, ... }:
{
#   Examples:
#   khttps://github.com/AlexNabokikh/nix-config/blob/master/modules/home-manager/desktop/kde/default.nix


  home.packages = with pkgs; [
    kde-rounded-corners
    kdePackages.kcalc
    kdePackages.krohnkite
  ];

  programs.plasma = {
    enable = true;

    workspace = {
      theme = "Nothing";
      lookAndFeel = "Nothing";
      cursor = {
        theme = "Breeze-Dark";
        size = 32;
      };
      iconTheme = "breeze-dark";
      wallpaperSlideShow = { path = "/home/facc/Pictures/walls/DesktopWallCopies/"; interval = 600; };
      wallpaperFillMode = "preserveAspectCrop";
    };
    kscreenlocker = {
      timeout = 10;
      passwordRequiredDelay = 5;
      appearance = {
        wallpaperSlideShow = { path = "/home/facc/Pictures/walls/DesktopWallCopies/"; interval = 600; };
#         wallpaperFillMode = "preserveAspectCrop";
      };
    };

    kwin = {
      virtualDesktops = {
        number = 3;
        rows = 2;
      };
      effects = {
        wobblyWindows.enable = true;
      };
      nightLight = {
        enable = true;
        mode = "times";
        time.evening = "21:30";
        time.morning = "06:00";
        transitionTime = 90;
        temperature.night = 4000;
      };
    };

    panels = [
      {
        location = "left";
        height = 40;
        opacity = "translucent";
        widgets = [
          { # Application launcher
            name = "org.kde.plasma.kickoff";
          }
          { # pager
            name = "org.dhruv8sh.kara";
            config = {
              general = {
                animationDuration = 0;
                highlightType = 1;
                spacing = 3;
                type = 1;
              };
              type1 = {
                fixedLen = 3;
                labelSource = 0;
              };
            };
          }
          { name = "org.kde.plasma.icontasks";   # Pinned apps
            config.Launchers = [
              "applications:brave.desktop"
              "applications:kitty.desktop"
              "applications:org.kde.dolphin.desktop"
            ];
          }
          { # System tray
#             name = "org.kde.plasma.systemtray";
            systemTray = {
              icons.scaleToFit = true;
              items = {
                showAll = false;
                shown = [
                  "org.kde.plasma.volume"
                  "org.kde.plasma.battery"
                  "org.kde.plasma.networkmanagement"
                ];
                hidden = [
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.brightness"
                  "org.kde.plasma.devicenotifier"
                  "org.kde.plasma.mediacontroller"
                  "plasmashell_microphone"
                  "xdg-desktop-portal-kde"
                  "org.kde.plasma.keyboardlayout"
                  "zoom"
                ];
                configs = {
                  "org.kde.plasma.notifications".config = {
                    Shortcuts = {
                      global = "Meta+N";
                    };
                  };
                };
              };
            };
          }
          { # Clock
            name = "org.kde.plasma.digitalclock";
            config = {
              Appearance = {
                autoFontAndSize = false;
                customDateFormat = "ddd MMM d";
                dateDisplayFormat = "BelowTime";
                dateFormat = "custom";
                fontSize = 11;
                fontStyleName = "Regular";
                fontWeight = 400;
                use24hFormat = 2;
              };
            };
          }
        ];
      }
    ];

    input.touchpads = [
      # /proc/bus/input/devices
      {
        enable = true;
        name = "VEN_04F3:00 04F3:32B1 Touchpad";
        naturalScroll = true;
        productId = "32b1";
        vendorId = "04f3";
      }
    ];

    powerdevil = {
      general.pausePlayersOnSuspend = true;
      AC = {
        autoSuspend.action = "nothing";
        powerButtonAction = "sleep";
        whenLaptopLidClosed = "doNothing";
        inhibitLidActionWhenExternalMonitorConnected = true;
        dimDisplay = {
          enable = true;
          idleTimeout = 540;
        };
        turnOffDisplay = {
          idleTimeout = 600;
          idleTimeoutWhenLocked = 30;
        };
      };
      battery = {
        powerProfile = "powerSaving"; ##
        autoSuspend.action = "nothing";
        powerButtonAction = "sleep";
        whenLaptopLidClosed = "doNothing";
        inhibitLidActionWhenExternalMonitorConnected = true;
        dimDisplay = {
          enable = true;
          idleTimeout = 60;
        };
        turnOffDisplay = {
          idleTimeout = 90;
          idleTimeoutWhenLocked = 20;
        };
      };
      batteryLevels = {
        criticalAction = "hibernate";
        criticalLevel = 5;
        lowLevel = 10;
      };
      lowBattery = {
        powerProfile = "powerSaving";
        autoSuspend.action = "sleep";
        powerButtonAction = "sleep";
        whenLaptopLidClosed = "doNothing";
        inhibitLidActionWhenExternalMonitorConnected = true;
        displayBrightness = 5; ##
        dimDisplay = {
          enable = true;
          idleTimeout = 20;
        };
        turnOffDisplay = {
          idleTimeout = 30;
          idleTimeoutWhenLocked = 20;
        };
      };
    };

    session.sessionRestore.restoreOpenApplicationsOnLogin = "onLastLogout";

#     window-rules = [
#       {
#         apply = {
#           desktops = "Desktop_1";
#           desktopsrule = "3";
#         };
#         description = "Assign Brave to Desktop 1";
#         match = {
#           window-class = {
#             value = "brave-browser";
#             type = "substring";
#           };
#           window-types = [ "normal" ];
#         };
#       }
#     ];

    # Hotkeys: make shortcuts for commands
    hotkeys.commands = {
      launch-brave = {
        name = "Launch Brave";
        key = "Meta+Shift+B";
        command = "brave";
      };
      launch-telegram = {
        name = "Launch Telegram";
        key = "Meta+Shift+T";
        command = "Telegram";
      };
    };

    # Shortcuts: Plasma shortcuts e.g. changing desktops etc
#     # rc2nix auto
    shortcuts = {
#       "ActivityManager"."switch-to-activity-459b3f65-1e51-43b4-9e16-72ca74d58795" = [ ];
#       "ActivityManager"."switch-to-activity-f3110254-86b9-43b9-a637-a25d083ad1c2" = [ ];
#       "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
#       "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";
#       "brave-browser"."6372DD4B8D6620CEA21602426701EE15-quick_clip" = [ ];
#       "brave-browser"."6372DD4B8D6620CEA21602426701EE15-toggle_highlighter" = [ ];
#       "brave-browser"."6372DD4B8D6620CEA21602426701EE15-toggle_reader" = [ ];
#       "kaccess"."Toggle Screen Reader On and Off" = "Meta+Alt+S";
#       "kmix"."decrease_microphone_volume" = "Microphone Volume Down";
#       "kmix"."decrease_volume" = "Volume Down";
#       "kmix"."decrease_volume_small" = "Shift+Volume Down";
#       "kmix"."increase_microphone_volume" = "Microphone Volume Up";
#       "kmix"."increase_volume" = "Volume Up";
#       "kmix"."increase_volume_small" = "Shift+Volume Up";
#       "kmix"."mic_mute" = ["Microphone Mute" "Meta+Volume Mute,Microphone Mute" "Meta+Volume Mute,Mute Microphone"];
#       "kmix"."mute" = "Volume Mute";
#       "ksmserver"."Halt Without Confirmation" = "none,,Shut Down Without Confirmation";
#       "ksmserver"."Lock Session" = ["Meta+L" "Screensaver,Meta+L" "Screensaver,Lock Session"];
#       "ksmserver"."Log Out" = "Ctrl+Alt+Del";
#       "ksmserver"."Log Out Without Confirmation" = "none,,Log Out Without Confirmation";
#       "ksmserver"."LogOut" = "none,,Log Out";
#       "ksmserver"."Reboot" = "none,,Reboot";
#       "ksmserver"."Reboot Without Confirmation" = "none,,Reboot Without Confirmation";
#       "ksmserver"."Shut Down" = "none,,Shut Down";
#       "kwin"."Activate Window Demanding Attention" = "Meta+Ctrl+A";
#       "kwin"."Cycle Overview" = [ ];
#       "kwin"."Cycle Overview Opposite" = [ ];
#       "kwin"."Decrease Opacity" = "none,,Decrease Opacity of Active Window by 5%";
#       "kwin"."Edit Tiles" = "Meta+T";
#       "kwin"."Expose" = "Ctrl+F9";
#       "kwin"."ExposeAll" = ["Ctrl+F10" "Launch (C),Ctrl+F10" "Launch (C),Toggle Present Windows (All desktops)"];
#       "kwin"."ExposeClass" = "Ctrl+F7";
#       "kwin"."ExposeClassCurrentDesktop" = [ ];
#       "kwin"."Grid View" = "Meta+G";
#       "kwin"."Increase Opacity" = "none,,Increase Opacity of Active Window by 5%";
#       "kwin"."Kill Window" = "Meta+Ctrl+Esc";
#       "kwin"."Move Tablet to Next Output" = [ ];
#       "kwin"."MoveMouseToCenter" = "Meta+F6";
#       "kwin"."MoveMouseToFocus" = "Meta+F5";
#       "kwin"."MoveZoomDown" = [ ];
#       "kwin"."MoveZoomLeft" = [ ];
#       "kwin"."MoveZoomRight" = [ ];
#       "kwin"."MoveZoomUp" = [ ];
#       "kwin"."Overview" = "Meta+W";
#       "kwin"."Setup Window Shortcut" = "none,,Setup Window Shortcut";
#       "kwin"."Show Desktop" = "Meta+D";
#       "kwin"."Suspend Compositing" = "Alt+Shift+F12";
#       "kwin"."Switch One Desktop Down" = "Meta+Ctrl+Down";
#       "kwin"."Switch One Desktop Up" = "Meta+Ctrl+Up";
#       "kwin"."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
#       "kwin"."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
#       "kwin"."Switch Window Down" = "Meta+Alt+Down";
#       "kwin"."Switch Window Left" = "Meta+Alt+Left";
#       "kwin"."Switch Window Right" = "Meta+Alt+Right";
#       "kwin"."Switch Window Up" = "Meta+Alt+Up";
#       "kwin"."Switch to Desktop 1" = "Ctrl+F1";
#       "kwin"."Switch to Desktop 10" = "none,,Switch to Desktop 10";
#       "kwin"."Switch to Desktop 11" = "none,,Switch to Desktop 11";
#       "kwin"."Switch to Desktop 12" = "none,,Switch to Desktop 12";
#       "kwin"."Switch to Desktop 13" = "none,,Switch to Desktop 13";
#       "kwin"."Switch to Desktop 14" = "none,,Switch to Desktop 14";
#       "kwin"."Switch to Desktop 15" = "none,,Switch to Desktop 15";
#       "kwin"."Switch to Desktop 16" = "none,,Switch to Desktop 16";
#       "kwin"."Switch to Desktop 17" = "none,,Switch to Desktop 17";
#       "kwin"."Switch to Desktop 18" = "none,,Switch to Desktop 18";
#       "kwin"."Switch to Desktop 19" = "none,,Switch to Desktop 19";
#       "kwin"."Switch to Desktop 2" = "Ctrl+F2";
#       "kwin"."Switch to Desktop 20" = "none,,Switch to Desktop 20";
#       "kwin"."Switch to Desktop 3" = "Ctrl+F3";
#       "kwin"."Switch to Desktop 4" = "Ctrl+F4";
#       "kwin"."Switch to Desktop 5" = "none,,Switch to Desktop 5";
#       "kwin"."Switch to Desktop 6" = "none,,Switch to Desktop 6";
#       "kwin"."Switch to Desktop 7" = "none,,Switch to Desktop 7";
#       "kwin"."Switch to Desktop 8" = "none,,Switch to Desktop 8";
#       "kwin"."Switch to Desktop 9" = "none,,Switch to Desktop 9";
#       "kwin"."Switch to Next Desktop" = "none,,Switch to Next Desktop";
#       "kwin"."Switch to Next Screen" = "none,,Switch to Next Screen";
#       "kwin"."Switch to Previous Desktop" = "none,,Switch to Previous Desktop";
#       "kwin"."Switch to Previous Screen" = "none,,Switch to Previous Screen";
#       "kwin"."Switch to Screen 0" = "none,,Switch to Screen 0";
#       "kwin"."Switch to Screen 1" = "none,,Switch to Screen 1";
#       "kwin"."Switch to Screen 2" = "none,,Switch to Screen 2";
#       "kwin"."Switch to Screen 3" = "none,,Switch to Screen 3";
#       "kwin"."Switch to Screen 4" = "none,,Switch to Screen 4";
#       "kwin"."Switch to Screen 5" = "none,,Switch to Screen 5";
#       "kwin"."Switch to Screen 6" = "none,,Switch to Screen 6";
#       "kwin"."Switch to Screen 7" = "none,,Switch to Screen 7";
#       "kwin"."Switch to Screen Above" = "none,,Switch to Screen Above";
#       "kwin"."Switch to Screen Below" = "none,,Switch to Screen Below";
#       "kwin"."Switch to Screen to the Left" = "none,,Switch to Screen to the Left";
#       "kwin"."Switch to Screen to the Right" = "none,,Switch to Screen to the Right";
#       "kwin"."Toggle Night Color" = [ ];
#       "kwin"."Toggle Window Raise/Lower" = "none,,Toggle Window Raise/Lower";
#       "kwin"."Walk Through Windows" = ["Alt+Tab,Meta+Tab" "Alt+Tab,Walk Through Windows"];
#       "kwin"."Walk Through Windows (Reverse)" = ["Alt+Shift+Tab,Meta+Shift+Tab" "Alt+Shift+Tab,Walk Through Windows (Reverse)"];
#       "kwin"."Walk Through Windows Alternative" = [ ];
#       "kwin"."Walk Through Windows Alternative (Reverse)" = [ ];
#       "kwin"."Walk Through Windows of Current Application" = ["Alt+`,Meta+`" "Alt+`,Walk Through Windows of Current Application"];
#       "kwin"."Walk Through Windows of Current Application (Reverse)" = ["Alt+~,Meta+~" "Alt+~,Walk Through Windows of Current Application (Reverse)"];
#       "kwin"."Walk Through Windows of Current Application Alternative" = [ ];
#       "kwin"."Walk Through Windows of Current Application Alternative (Reverse)" = [ ];
#       "kwin"."Window Above Other Windows" = "none,,Keep Window Above Others";
#       "kwin"."Window Below Other Windows" = "none,,Keep Window Below Others";
#       "kwin"."Window Close" = "Alt+F4";
#       "kwin"."Window Custom Quick Tile Bottom" = "none,,Custom Quick Tile Window to the Bottom";
#       "kwin"."Window Custom Quick Tile Left" = "none,,Custom Quick Tile Window to the Left";
#       "kwin"."Window Custom Quick Tile Right" = "none,,Custom Quick Tile Window to the Right";
#       "kwin"."Window Custom Quick Tile Top" = "none,,Custom Quick Tile Window to the Top";
#       "kwin"."Window Fullscreen" = "none,,Make Window Fullscreen";
#       "kwin"."Window Grow Horizontal" = "none,,Expand Window Horizontally";
#       "kwin"."Window Grow Vertical" = "none,,Expand Window Vertically";
#       "kwin"."Window Lower" = "none,,Lower Window";
#       "kwin"."Window Maximize" = "Meta+PgUp";
#       "kwin"."Window Maximize Horizontal" = "none,,Maximize Window Horizontally";
#       "kwin"."Window Maximize Vertical" = "none,,Maximize Window Vertically";
#       "kwin"."Window Minimize" = "Meta+PgDown";
#       "kwin"."Window Move" = "none,,Move Window";
#       "kwin"."Window Move Center" = "none,,Move Window to the Center";
#       "kwin"."Window No Border" = "none,,Toggle Window Titlebar and Frame";
#       "kwin"."Window On All Desktops" = "none,,Keep Window on All Desktops";
#       "kwin"."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
#       "kwin"."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
#       "kwin"."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
#       "kwin"."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
#       "kwin"."Window One Screen Down" = "none,,Move Window One Screen Down";
#       "kwin"."Window One Screen Up" = "none,,Move Window One Screen Up";
#       "kwin"."Window One Screen to the Left" = "none,,Move Window One Screen to the Left";
#       "kwin"."Window One Screen to the Right" = "none,,Move Window One Screen to the Right";
#       "kwin"."Window Operations Menu" = "Alt+F3";
#       "kwin"."Window Pack Down" = "none,,Move Window Down";
#       "kwin"."Window Pack Left" = "none,,Move Window Left";
#       "kwin"."Window Pack Right" = "none,,Move Window Right";
#       "kwin"."Window Pack Up" = "none,,Move Window Up";
#       "kwin"."Window Quick Tile Bottom" = "Meta+Down";
#       "kwin"."Window Quick Tile Bottom Left" = "none,,Quick Tile Window to the Bottom Left";
#       "kwin"."Window Quick Tile Bottom Right" = "none,,Quick Tile Window to the Bottom Right";
#       "kwin"."Window Quick Tile Left" = "Meta+Left";
#       "kwin"."Window Quick Tile Right" = "Meta+Right";
#       "kwin"."Window Quick Tile Top" = "Meta+Up";
#       "kwin"."Window Quick Tile Top Left" = "none,,Quick Tile Window to the Top Left";
#       "kwin"."Window Quick Tile Top Right" = "none,,Quick Tile Window to the Top Right";
#       "kwin"."Window Raise" = "none,,Raise Window";
#       "kwin"."Window Resize" = "none,,Resize Window";
#       "kwin"."Window Shade" = "none,,Shade Window";
#       "kwin"."Window Shrink Horizontal" = "none,,Shrink Window Horizontally";
#       "kwin"."Window Shrink Vertical" = "none,,Shrink Window Vertically";
#       "kwin"."Window to Desktop 1" = "none,,Window to Desktop 1";
#       "kwin"."Window to Desktop 10" = "none,,Window to Desktop 10";
#       "kwin"."Window to Desktop 11" = "none,,Window to Desktop 11";
#       "kwin"."Window to Desktop 12" = "none,,Window to Desktop 12";
#       "kwin"."Window to Desktop 13" = "none,,Window to Desktop 13";
#       "kwin"."Window to Desktop 14" = "none,,Window to Desktop 14";
#       "kwin"."Window to Desktop 15" = "none,,Window to Desktop 15";
#       "kwin"."Window to Desktop 16" = "none,,Window to Desktop 16";
#       "kwin"."Window to Desktop 17" = "none,,Window to Desktop 17";
#       "kwin"."Window to Desktop 18" = "none,,Window to Desktop 18";
#       "kwin"."Window to Desktop 19" = "none,,Window to Desktop 19";
#       "kwin"."Window to Desktop 2" = "none,,Window to Desktop 2";
#       "kwin"."Window to Desktop 20" = "none,,Window to Desktop 20";
#       "kwin"."Window to Desktop 3" = "none,,Window to Desktop 3";
#       "kwin"."Window to Desktop 4" = "none,,Window to Desktop 4";
#       "kwin"."Window to Desktop 5" = "none,,Window to Desktop 5";
#       "kwin"."Window to Desktop 6" = "none,,Window to Desktop 6";
#       "kwin"."Window to Desktop 7" = "none,,Window to Desktop 7";
#       "kwin"."Window to Desktop 8" = "none,,Window to Desktop 8";
#       "kwin"."Window to Desktop 9" = "none,,Window to Desktop 9";
#       "kwin"."Window to Next Desktop" = "none,,Window to Next Desktop";
#       "kwin"."Window to Next Screen" = "Meta+Shift+Right";
#       "kwin"."Window to Previous Desktop" = "none,,Window to Previous Desktop";
#       "kwin"."Window to Previous Screen" = "Meta+Shift+Left";
#       "kwin"."Window to Screen 0" = "none,,Move Window to Screen 0";
#       "kwin"."Window to Screen 1" = "none,,Move Window to Screen 1";
#       "kwin"."Window to Screen 2" = "none,,Move Window to Screen 2";
#       "kwin"."Window to Screen 3" = "none,,Move Window to Screen 3";
#       "kwin"."Window to Screen 4" = "none,,Move Window to Screen 4";
#       "kwin"."Window to Screen 5" = "none,,Move Window to Screen 5";
#       "kwin"."Window to Screen 6" = "none,,Move Window to Screen 6";
#       "kwin"."Window to Screen 7" = "none,,Move Window to Screen 7";
#       "kwin"."disableInputCapture" = "Meta+Shift+Esc";
#       "kwin"."view_actual_size" = "Meta+0";
#       "kwin"."view_zoom_in" = ["Meta++" "Meta+=,Meta++" "Meta+=,Zoom In"];
#       "kwin"."view_zoom_out" = "Meta+-";
#       "mediacontrol"."mediavolumedown" = "none,,Media volume down";
#       "mediacontrol"."mediavolumeup" = "none,,Media volume up";
#       "mediacontrol"."nextmedia" = "Media Next";
#       "mediacontrol"."pausemedia" = "Media Pause";
#       "mediacontrol"."playmedia" = "none,,Play media playback";
#       "mediacontrol"."playpausemedia" = "Media Play";
#       "mediacontrol"."previousmedia" = "Media Previous";
#       "mediacontrol"."stopmedia" = "Media Stop";
#       "org_kde_powerdevil"."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
#       "org_kde_powerdevil"."Decrease Screen Brightness" = "Monitor Brightness Down";
#       "org_kde_powerdevil"."Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
#       "org_kde_powerdevil"."Hibernate" = "Hibernate";
#       "org_kde_powerdevil"."Increase Keyboard Brightness" = "Keyboard Brightness Up";
#       "org_kde_powerdevil"."Increase Screen Brightness" = "Monitor Brightness Up";
#       "org_kde_powerdevil"."Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
#       "org_kde_powerdevil"."PowerDown" = "Power Down";
#       "org_kde_powerdevil"."PowerOff" = "Power Off";
#       "org_kde_powerdevil"."Sleep" = "Sleep";
#       "org_kde_powerdevil"."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
#       "org_kde_powerdevil"."Turn Off Screen" = "Meta+F7,none,Turn Off Screen";
#       "org_kde_powerdevil"."powerProfile" = ["Battery" "Meta+B,Battery" "Meta+B,Switch Power Profile"];
#       "plasmashell"."activate application launcher" = ["Meta" "Alt+F1,Meta" "Alt+F1,Activate Application Launcher"];
#       "plasmashell"."activate task manager entry 1" = "Meta+1";
#       "plasmashell"."activate task manager entry 10" = "none,,Activate Task Manager Entry 10";
#       "plasmashell"."activate task manager entry 2" = "Meta+2";
#       "plasmashell"."activate task manager entry 3" = "Meta+3";
#       "plasmashell"."activate task manager entry 4" = "Meta+4";
#       "plasmashell"."activate task manager entry 5" = "Meta+5";
#       "plasmashell"."activate task manager entry 6" = "Meta+6";
#       "plasmashell"."activate task manager entry 7" = "Meta+7";
#       "plasmashell"."activate task manager entry 8" = "Meta+8";
#       "plasmashell"."activate task manager entry 9" = "Meta+9";
#       "plasmashell"."clear-history" = "none,,Clear Clipboard History";
#       "plasmashell"."clipboard_action" = "Meta+Ctrl+X";
#       "plasmashell"."cycle-panels" = "Meta+Alt+P";
#       "plasmashell"."cycleNextAction" = "none,,Next History Item";
#       "plasmashell"."cyclePrevAction" = "none,,Previous History Item";
#       "plasmashell"."edit_clipboard" = "none,,Edit Contents…";
#       "plasmashell"."manage activities" = "Meta+Q";
      "plasmashell"."next activity" = "Meta+Tab";
#       "plasmashell"."previous activity" = [ ];
#       "plasmashell"."repeat_action" = "none,,Manually Invoke Action on Current Clipboard";
#       "plasmashell"."show dashboard" = "Ctrl+F12";
#       "plasmashell"."show-barcode" = "none,,Show Barcode…";
#       "plasmashell"."show-on-mouse-pos" = "Meta+V";
#       "plasmashell"."stop current activity" = "Meta+S";
#       "plasmashell"."switch to next activity" = "none,,Switch to Next Activity";
#       "plasmashell"."switch to previous activity" = "none,,Switch to Previous Activity";
#       "plasmashell"."toggle do not disturb" = "none,,Toggle do not disturb";
#       "services/org.kde.touchpadshortcuts.desktop"."ToggleTouchpad" = ["Touchpad Toggle" "Meta+Ctrl+Zenkaku Hankaku"];
    };
    configFile = {
      kwinrc = {
        Effect-overview.BorderActivate = 9;
        Plugins = {
          krohnkiteEnabled = true;
#           screenedgeEnabled = false;
        };
        "Round-Corners" = {
          ActiveOutlineAlpha = 255;
          ActiveOutlineUseCustom = false;
          ActiveOutlineUsePalette = true;
          DisableOutlineTile = false;
          DisableRoundTile = false;
          InactiveCornerRadius = 8;
          InactiveOutlineAlpha = 0;
          InactiveSecondOutlineThickness = 0;
          OutlineThickness = 1;
          SecondOutlineThickness = 0;
          Size = 8;
        };
        "Script-krohnkite" = {
          floatingClass = "brave-nngceckbapebfimnlniiiahkandclblb-Default,org.kde.kcalc,org.freedesktop.impl.portal.desktop.kde";
          screenGapBetween = 6;
          screenGapBottom = 6;
          screenGapLeft = 6;
          screenGapRight = 6;
          screenGapTop = 6;
        };
        Windows = {
          DelayFocusInterval = 0;
          FocusPolicy = "FocusFollowsMouse";
        };
      };
      plasmanotifyrc = {
        DoNotDisturb = {
          WhenFullscreen = false;
          WhenScreenSharing = false;
          WhenScreensMirrored = false;
        };
        Notifications = {
          PopupPosition = "BottomRight";
          PopupTimeout = 7000;
        };
      };
    ### auto:
#       "baloofilerc"."General"."dbVersion" = 2;
#       "baloofilerc"."General"."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
#       "baloofilerc"."General"."exclude filters version" = 9;
      "kactivitymanagerdrc"."activities"."f3110254-86b9-43b9-a637-a25d083ad1c2" = "1W";
      "kactivitymanagerdrc"."activities"."459b3f65-1e51-43b4-9e16-72ca74d58795" = "2P";
      "kactivitymanagerdrc"."activities-icons"."f3110254-86b9-43b9-a637-a25d083ad1c2" = "labplot";
      "kactivitymanagerdrc"."activities-icons"."459b3f65-1e51-43b4-9e16-72ca74d58795" = "usb-creator-kde";
      "kactivitymanagerdrc"."main"."currentActivity" = "f3110254-86b9-43b9-a637-a25d083ad1c2";
#       "katerc"."General"."Allow Tab Scrolling" = true;
#       "katerc"."General"."Auto Hide Tabs" = false;
#       "katerc"."General"."Close After Last" = false;
#       "katerc"."General"."Close documents with window" = true;
#       "katerc"."General"."Cycle To First Tab" = true;
#       "katerc"."General"."Days Meta Infos" = 30;
#       "katerc"."General"."Diagnostics Limit" = 12000;
#       "katerc"."General"."Diff Show Style" = 0;
#       "katerc"."General"."Elide Tab Text" = false;
#       "katerc"."General"."Enable Context ToolView" = false;
#       "katerc"."General"."Expand Tabs" = false;
#       "katerc"."General"."Icon size for left and right sidebar buttons" = 32;
#       "katerc"."General"."Modified Notification" = false;
#       "katerc"."General"."Mouse back button action" = 0;
#       "katerc"."General"."Mouse forward button action" = 0;
#       "katerc"."General"."Open New Tab To The Right Of Current" = false;
#       "katerc"."General"."Output History Limit" = 100;
#       "katerc"."General"."Output With Date" = false;
#       "katerc"."General"."Recent File List Entry Count" = 10;
#       "katerc"."General"."Restore Window Configuration" = true;
#       "katerc"."General"."SDI Mode" = false;
#       "katerc"."General"."Save Meta Infos" = true;
#       "katerc"."General"."Show Full Path in Title" = true;
#       "katerc"."General"."Show Menu Bar" = true;
#       "katerc"."General"."Show Status Bar" = true;
#       "katerc"."General"."Show Symbol In Navigation Bar" = true;
#       "katerc"."General"."Show Tab Bar" = true;
#       "katerc"."General"."Show Tabs Close Button" = true;
#       "katerc"."General"."Show Url Nav Bar" = true;
#       "katerc"."General"."Show output view for message type" = 1;
#       "katerc"."General"."Show text for left and right sidebar" = false;
#       "katerc"."General"."Show welcome view for new window" = true;
#       "katerc"."General"."Startup Session" = "manual";
#       "katerc"."General"."Stash new unsaved files" = true;
#       "katerc"."General"."Stash unsaved file changes" = false;
#       "katerc"."General"."Sync section size with tab positions" = false;
#       "katerc"."General"."Tab Double Click New Document" = true;
#       "katerc"."General"."Tab Middle Click Close Document" = true;
#       "katerc"."General"."Tabbar Tab Limit" = 0;
#       "katerc"."KTextEditor View"."Allow Mark Menu" = true;
#       "katerc"."KTextEditor View"."Auto Brackets" = true;
#       "katerc"."KTextEditor View"."Auto Center Lines" = 0;
#       "katerc"."KTextEditor View"."Auto Completion" = false;
#       "katerc"."KTextEditor View"."Auto Completion Preselect First Entry" = true;
#       "katerc"."KTextEditor View"."Backspace Remove Composed Characters" = false;
#       "katerc"."KTextEditor View"."Bookmark Menu Sorting" = 0;
#       "katerc"."KTextEditor View"."Bracket Match Preview" = false;
#       "katerc"."KTextEditor View"."Chars To Enclose Selection" = "<>(){}[]'\"";
#       "katerc"."KTextEditor View"."Cycle Through Bookmarks" = true;
#       "katerc"."KTextEditor View"."Default Mark Type" = 1;
#       "katerc"."KTextEditor View"."Dynamic Word Wrap" = true;
#       "katerc"."KTextEditor View"."Dynamic Word Wrap Align Indent" = 80;
#       "katerc"."KTextEditor View"."Dynamic Word Wrap At Static Marker" = false;
#       "katerc"."KTextEditor View"."Dynamic Word Wrap Indicators" = 1;
#       "katerc"."KTextEditor View"."Dynamic Wrap not at word boundaries" = false;
#       "katerc"."KTextEditor View"."Enable Accessibility" = true;
#       "katerc"."KTextEditor View"."Enable Tab completion" = false;
#       "katerc"."KTextEditor View"."Enter To Insert Completion" = true;
#       "katerc"."KTextEditor View"."Fold First Line" = false;
#       "katerc"."KTextEditor View"."Folding Bar" = true;
#       "katerc"."KTextEditor View"."Folding Preview" = true;
#       "katerc"."KTextEditor View"."Icon Bar" = false;
#       "katerc"."KTextEditor View"."Input Mode" = 0;
#       "katerc"."KTextEditor View"."Keyword Completion" = true;
#       "katerc"."KTextEditor View"."Line Modification" = true;
#       "katerc"."KTextEditor View"."Line Numbers" = true;
#       "katerc"."KTextEditor View"."Max Clipboard History Entries" = 20;
#       "katerc"."KTextEditor View"."Maximum Search History Size" = 100;
#       "katerc"."KTextEditor View"."Mouse Paste At Cursor Position" = false;
#       "katerc"."KTextEditor View"."Multiple Cursor Modifier" = 134217728;
#       "katerc"."KTextEditor View"."Persistent Selection" = false;
#       "katerc"."KTextEditor View"."Scroll Bar Marks" = false;
#       "katerc"."KTextEditor View"."Scroll Bar Mini Map All" = true;
#       "katerc"."KTextEditor View"."Scroll Bar Mini Map Width" = 60;
#       "katerc"."KTextEditor View"."Scroll Bar MiniMap" = true;
#       "katerc"."KTextEditor View"."Scroll Bar Preview" = true;
#       "katerc"."KTextEditor View"."Scroll Past End" = false;
#       "katerc"."KTextEditor View"."Search/Replace Flags" = 140;
#       "katerc"."KTextEditor View"."Shoe Line Ending Type in Statusbar" = false;
#       "katerc"."KTextEditor View"."Show Documentation With Completion" = true;
#       "katerc"."KTextEditor View"."Show File Encoding" = true;
#       "katerc"."KTextEditor View"."Show Folding Icons On Hover Only" = true;
#       "katerc"."KTextEditor View"."Show Line Count" = false;
#       "katerc"."KTextEditor View"."Show Scrollbars" = 0;
#       "katerc"."KTextEditor View"."Show Statusbar Dictionary" = true;
#       "katerc"."KTextEditor View"."Show Statusbar Highlighting Mode" = true;
#       "katerc"."KTextEditor View"."Show Statusbar Input Mode" = true;
#       "katerc"."KTextEditor View"."Show Statusbar Line Column" = true;
#       "katerc"."KTextEditor View"."Show Statusbar Tab Settings" = true;
#       "katerc"."KTextEditor View"."Show Word Count" = false;
#       "katerc"."KTextEditor View"."Smart Copy Cut" = true;
#       "katerc"."KTextEditor View"."Statusbar Line Column Compact Mode" = true;
#       "katerc"."KTextEditor View"."Text Drag And Drop" = true;
#       "katerc"."KTextEditor View"."User Sets Of Chars To Enclose Selection" = "";
#       "katerc"."KTextEditor View"."Vi Input Mode Steal Keys" = false;
#       "katerc"."KTextEditor View"."Vi Relative Line Numbers" = false;
#       "katerc"."KTextEditor View"."Word Completion" = true;
#       "katerc"."KTextEditor View"."Word Completion Minimal Word Length" = 3;
#       "katerc"."KTextEditor View"."Word Completion Remove Tail" = true;
#       "katerc"."Konsole"."AutoSyncronizeMode" = 0;
#       "katerc"."Konsole"."KonsoleEscKeyBehaviour" = true;
#       "katerc"."Konsole"."KonsoleEscKeyExceptions" = "vi,vim,nvim,git";
#       "katerc"."Konsole"."RemoveExtension" = false;
#       "katerc"."Konsole"."RunPrefix" = "";
#       "katerc"."Konsole"."SetEditor" = false;
#       "katerc"."filetree"."editShade" = "183,220,246";
#       "katerc"."filetree"."listMode" = false;
#       "katerc"."filetree"."middleClickToClose" = false;
#       "katerc"."filetree"."shadingEnabled" = true;
#       "katerc"."filetree"."showCloseButton" = false;
#       "katerc"."filetree"."showFullPathOnRoots" = false;
#       "katerc"."filetree"."showToolbar" = true;
#       "katerc"."filetree"."sortRole" = 0;
#       "katerc"."filetree"."viewShade" = "211,190,222";
#       "katerc"."lspclient"."AllowedServerCommandLines" = "";
#       "katerc"."lspclient"."AutoHover" = true;
#       "katerc"."lspclient"."AutoImport" = true;
#       "katerc"."lspclient"."BlockedServerCommandLines" = "";
#       "katerc"."lspclient"."CompletionDocumentation" = true;
#       "katerc"."lspclient"."CompletionParens" = true;
#       "katerc"."lspclient"."Diagnostics" = true;
#       "katerc"."lspclient"."FormatOnSave" = false;
#       "katerc"."lspclient"."HighlightGoto" = true;
#       "katerc"."lspclient"."IncrementalSync" = false;
#       "katerc"."lspclient"."InlayHints" = false;
#       "katerc"."lspclient"."Messages" = true;
#       "katerc"."lspclient"."ReferencesDeclaration" = true;
#       "katerc"."lspclient"."SemanticHighlighting" = true;
#       "katerc"."lspclient"."ServerConfiguration" = "";
#       "katerc"."lspclient"."ShowCompletions" = true;
#       "katerc"."lspclient"."SignatureHelp" = true;
#       "katerc"."lspclient"."SymbolDetails" = false;
#       "katerc"."lspclient"."SymbolExpand" = true;
#       "katerc"."lspclient"."SymbolSort" = false;
#       "katerc"."lspclient"."SymbolTree" = true;
#       "katerc"."lspclient"."TypeFormatting" = false;
# #       "kcminputrc"."Libinput/1267/12977/VEN_04F3:00 04F3:32B1 Touchpad"."NaturalScroll" = true;
# #       "kcminputrc"."Libinput/1267/12977/VEN_04F3:00 04F3:32B1 Touchpad"."PointerAcceleration" = 0.000;
# #       "kcminputrc"."Libinput/1267/12977/VEN_04F3:00 04F3:32B1 Touchpad"."PointerAccelerationProfile" = 2;
#       "kcminputrc"."Mouse"."X11LibInputXAccelProfileFlat" = true;
#       "kded5rc"."Module-device_automounter"."autoload" = false;
#       "kdeglobals"."DirSelect Dialog"."DirSelectDialog Size" = "981,526";
#       "kdeglobals"."DirSelect Dialog"."Splitter State" = "\x00\x00\x00\xff\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\x8c\x00\x00\x02\xa8\x00\xff\xff\xff\xff\x01\x00\x00\x00\x01\x00";
#       "kdeglobals"."KFileDialog Settings"."Allow Expansion" = false;
#       "kdeglobals"."KFileDialog Settings"."Automatically select filename extension" = true;
#       "kdeglobals"."KFileDialog Settings"."Breadcrumb Navigation" = false;
#       "kdeglobals"."KFileDialog Settings"."Decoration position" = 2;
#       "kdeglobals"."KFileDialog Settings"."LocationCombo Completionmode" = 5;
#       "kdeglobals"."KFileDialog Settings"."PathCombo Completionmode" = 5;
#       "kdeglobals"."KFileDialog Settings"."Show Bookmarks" = false;
#       "kdeglobals"."KFileDialog Settings"."Show Full Path" = false;
#       "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
#       "kdeglobals"."KFileDialog Settings"."Show Preview" = false;
#       "kdeglobals"."KFileDialog Settings"."Show Speedbar" = true;
#       "kdeglobals"."KFileDialog Settings"."Show hidden files" = false;
#       "kdeglobals"."KFileDialog Settings"."Sort by" = "Name";
#       "kdeglobals"."KFileDialog Settings"."Sort directories first" = true;
#       "kdeglobals"."KFileDialog Settings"."Sort hidden files last" = false;
#       "kdeglobals"."KFileDialog Settings"."Sort reversed" = false;
#       "kdeglobals"."KFileDialog Settings"."Speedbar Width" = 140;
#       "kdeglobals"."KFileDialog Settings"."View Style" = "DetailTree";
#       "kdeglobals"."KScreen"."ScaleFactor" = 1.5;
#       "kdeglobals"."KScreen"."ScreenScaleFactors" = "eDP-1=1.5;DP-1=1.5;DP-1-0=1.5;DP-1-1=1.5;DP-1-2=1.5;DP-1-3=1.5;HDMI-1-0=1.5;DP-1-4=1.5;";
#       "kdeglobals"."KShortcutsDialog Settings"."Dialog Size" = "600,480";
#       "kdeglobals"."PreviewSettings"."EnableRemoteFolderThumbnail" = false;
#       "kdeglobals"."PreviewSettings"."MaximumRemoteSize" = 0;
#       "kdeglobals"."WM"."activeBackground" = "39,44,49";
#       "kdeglobals"."WM"."activeBlend" = "252,252,252";
#       "kdeglobals"."WM"."activeForeground" = "252,252,252";
#       "kdeglobals"."WM"."inactiveBackground" = "32,36,40";
#       "kdeglobals"."WM"."inactiveBlend" = "161,169,177";
#       "kdeglobals"."WM"."inactiveForeground" = "161,169,177";
#       "kiorc"."Confirmations"."ConfirmDelete" = true;
#       "kiorc"."Confirmations"."ConfirmEmptyTrash" = true;
#       "kiorc"."Confirmations"."ConfirmTrash" = false;
#       "kiorc"."Executable scripts"."behaviourOnLaunch" = "alwaysAsk";
#       "kscreenlockerrc"."Greeter"."WallpaperPlugin" = "org.kde.slideshow";
# #       "kscreenlockerrc"."Greeter/Wallpaper/org.kde.slideshow/General"."Image" = "file:///home/facc/Pictures/walls/DesktopWallCopies/mononoke026.jpg";
# #       "kscreenlockerrc"."Greeter/Wallpaper/org.kde.slideshow/General"."SlidePaths" = "/home/facc/Pictures/walls/DesktopWallCopies/";
#       "ktrashrc"."\\/home\\/facc\\/.local\\/share\\/Trash"."Days" = 7;
#       "ktrashrc"."\\/home\\/facc\\/.local\\/share\\/Trash"."LimitReachedAction" = 0;
#       "ktrashrc"."\\/home\\/facc\\/.local\\/share\\/Trash"."Percent" = 10;
#       "ktrashrc"."\\/home\\/facc\\/.local\\/share\\/Trash"."UseSizeLimit" = true;
#       "ktrashrc"."\\/home\\/facc\\/.local\\/share\\/Trash"."UseTimeLimit" = false;
#       "kwalletrc"."Wallet"."First Use" = false;
#       "kwinrc"."Activities/LastVirtualDesktop"."459b3f65-1e51-43b4-9e16-72ca74d58795" = "fe98c4a4-a8ef-4c97-89d0-8361d9782dad";
#       "kwinrc"."Activities/LastVirtualDesktop"."f3110254-86b9-43b9-a637-a25d083ad1c2" = "fe98c4a4-a8ef-4c97-89d0-8361d9782dad";
# #       "kwinrc"."Desktops"."Id_1" = "fe98c4a4-a8ef-4c97-89d0-8361d9782dad";
# #       "kwinrc"."Desktops"."Id_2" = "b6900b11-4bc7-413e-8a35-06fe657de138";
# #       "kwinrc"."Desktops"."Id_3" = "c34ae44d-cbf4-4043-95b3-a54317012ad3";
# #       "kwinrc"."Desktops"."Number" = 3;
# #       "kwinrc"."Desktops"."Rows" = 2;
#       "kwinrc"."Effect-wobblywindows"."Drag" = 85;
#       "kwinrc"."Effect-wobblywindows"."Stiffness" = 10;
#       "kwinrc"."Effect-wobblywindows"."WobblynessLevel" = 1;
#       "kwinrc"."NightColor"."Active" = true;
#       "kwinrc"."NightColor"."EveningBeginFixed" = 2130;
#       "kwinrc"."NightColor"."Mode" = "Times";
#       "kwinrc"."NightColor"."NightTemperature" = 4000;
#       "kwinrc"."NightColor"."TransitionTime" = 90;
#       "kwinrc"."Plugins"."wobblywindowsEnabled" = true;
#       "kwinrc"."Tiling"."padding" = 4;
#       "kwinrc"."Tiling/0871df60-8da5-57a7-8ed0-dd3edb082730"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/089984be-bd5c-5a63-857a-b2555cf7f37c"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/0b08a372-5d43-5853-93da-3a1afbbfa1b3"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/2b074c5f-97f1-5966-8565-b87a80fd03e2"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/953a16fb-952c-5bc5-8f3a-0820547fbc72"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/b6900b11-4bc7-413e-8a35-06fe657de138/6fa613a1-bc13-45dc-90a1-5fd2d31d90ff"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/b6900b11-4bc7-413e-8a35-06fe657de138/6fc23c6e-0dbf-4c56-9f19-2173a7f4635f"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/c34ae44d-cbf4-4043-95b3-a54317012ad3/6fa613a1-bc13-45dc-90a1-5fd2d31d90ff"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/c34ae44d-cbf4-4043-95b3-a54317012ad3/6fc23c6e-0dbf-4c56-9f19-2173a7f4635f"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/cf67af27-c496-552c-bd97-7af80988b4ea"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/fe98c4a4-a8ef-4c97-89d0-8361d9782dad/6fa613a1-bc13-45dc-90a1-5fd2d31d90ff"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Tiling/fe98c4a4-a8ef-4c97-89d0-8361d9782dad/6fc23c6e-0dbf-4c56-9f19-2173a7f4635f"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
#       "kwinrc"."Xwayland"."Scale" = 1.4;
#       "plasma-localerc"."Formats"."LANG" = "en_US.UTF-8";
#       "plasmanotifyrc"."Applications/beepertexts"."Seen" = true;
#       "plasmanotifyrc"."Applications/brave-browser"."Seen" = true;
#       "plasmanotifyrc"."Applications/com.github.persepolisdm.persepolis"."Seen" = true;
#       "plasmanotifyrc"."Applications/org.telegram.desktop"."Seen" = true;
#       "plasmarc"."Wallpapers"."usersWallpapers" = "";
#       "spectaclerc"."Annotations"."annotationToolType" = 2;
#       "spectaclerc"."Annotations"."freehandStrokeColor" = "170,0,0";
#       "spectaclerc"."Annotations"."rectangleStrokeColor" = "170,0,0";
#       "spectaclerc"."ImageSave"."lastImageSaveAsLocation" = "file:///home/facc/Documents/THOP/pics/jetpack_2025-07-27.png";
#       "spectaclerc"."ImageSave"."lastImageSaveLocation" = "file:///home/facc/Pictures/Screenshots/Screenshot_20250804_175841.png";
#       "spectaclerc"."ImageSave"."translatedScreenshotsFolder" = "Screenshots";
#       "spectaclerc"."VideoSave"."translatedScreencastsFolder" = "Screencasts";
#     };
#     dataFile = {
#       "kate/anonymous.katesession"."Document 0"."URL" = "file:///home/facc/.config/dolphinrc";
#       "kate/anonymous.katesession"."Kate Plugins"."cmaketoolsplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."compilerexplorer" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."eslintplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."externaltoolsplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."formatplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katebacktracebrowserplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katebuildplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katecloseexceptplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katecolorpickerplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katectagsplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katefilebrowserplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katefiletreeplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."kategdbplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."kategitblameplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katekonsoleplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."kateprojectplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."katereplicodeplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katesearchplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."katesnippetsplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katesqlplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katesymbolviewerplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katexmlcheckplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."katexmltoolsplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."keyboardmacrosplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."ktexteditorpreviewplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."latexcompletionplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."lspclientplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."openlinkplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."rainbowparens" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."rbqlplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."tabswitcherplugin" = true;
#       "kate/anonymous.katesession"."Kate Plugins"."templateplugin" = false;
#       "kate/anonymous.katesession"."Kate Plugins"."textfilterplugin" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Active ViewSpace" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-H-Splitter" = "0,1739,0";
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-0-Bar-0-TvList" = "kate_private_plugin_katefiletreeplugin,kateproject,kateprojectgit,lspclient_symbol_outline";
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-0-LastSize" = 200;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-0-SectSizes" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-0-Splitter" = 1005;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-1-Bar-0-TvList" = "";
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-1-LastSize" = 200;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-1-SectSizes" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-1-Splitter" = 1005;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-2-Bar-0-TvList" = "";
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-2-LastSize" = 200;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-2-SectSizes" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-2-Splitter" = 1739;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-3-Bar-0-TvList" = "output,diagnostics,kate_plugin_katesearch,kateprojectinfo,kate_private_plugin_katekonsoleplugin";
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-3-LastSize" = 204;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-3-SectSizes" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-3-Splitter" = 1492;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-Style" = 2;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-Sidebar-Visible" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-diagnostics-Position" = 3;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-diagnostics-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-diagnostics-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_plugin_katesearch-Position" = 3;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_plugin_katesearch-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_plugin_katesearch-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katefiletreeplugin-Position" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katefiletreeplugin-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katefiletreeplugin-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katekonsoleplugin-Position" = 3;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katekonsoleplugin-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kate_private_plugin_katekonsoleplugin-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateproject-Position" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateproject-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateproject-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectgit-Position" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectgit-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectgit-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectinfo-Position" = 3;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectinfo-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-kateprojectinfo-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-lspclient_symbol_outline-Position" = 0;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-lspclient_symbol_outline-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-lspclient_symbol_outline-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-output-Position" = 3;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-output-Show-Button-In-Sidebar" = true;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-ToolView-output-Visible" = false;
#       "kate/anonymous.katesession"."MainWindow0"."Kate-MDI-V-Splitter" = "0,1005,0";
#       "kate/anonymous.katesession"."MainWindow0 Settings"."WindowState" = 10;
#       "kate/anonymous.katesession"."MainWindow0-Splitter 0"."Children" = "MainWindow0-ViewSpace 0";
#       "kate/anonymous.katesession"."MainWindow0-Splitter 0"."Orientation" = 2;
#       "kate/anonymous.katesession"."MainWindow0-Splitter 0"."Sizes" = 1005;
#       "kate/anonymous.katesession"."MainWindow0-ViewSpace 0"."Active View" = 0;
#       "kate/anonymous.katesession"."MainWindow0-ViewSpace 0"."Count" = 1;
#       "kate/anonymous.katesession"."MainWindow0-ViewSpace 0"."Documents" = 0;
#       "kate/anonymous.katesession"."MainWindow0-ViewSpace 0"."View 0" = 0;
#       "kate/anonymous.katesession"."Open Documents"."Count" = 1;
#       "kate/anonymous.katesession"."Open MainWindows"."Count" = 1;
#       "kate/anonymous.katesession"."Plugin:kateprojectplugin:"."projects" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."BinaryFiles" = false;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."CurrentExcludeFilter" = "-1";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."CurrentFilter" = "-1";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."ExcludeFilters" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."ExpandSearchResults" = false;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."Filters" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."FollowSymLink" = false;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."HiddenFiles" = false;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."MatchCase" = false;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."Place" = 1;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."Recursive" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."Replaces" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."Search" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchAsYouTypeAllProjects" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchAsYouTypeCurrentFile" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchAsYouTypeFolder" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchAsYouTypeOpenFiles" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchAsYouTypeProject" = true;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchDiskFiles" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SearchDiskFiless" = "";
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."SizeLimit" = 128;
#       "kate/anonymous.katesession"."Plugin:katesearchplugin:MainWindow:0"."UseRegExp" = false;
    };
  };
}
