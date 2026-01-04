{
  programs.plasma = {
    configFile = {
      plasma_calendar_holiday_regions.General.selectedRegions = "it_it-it";
      plasma_calendar_astronomicalevents.General = {
        showLunarPhase = true;
        showSeason = true;
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
    };

    panels = [
#       # Dock
#       {
#         location = "left";
#         height = 40;
# #         alignment = "center";
#         floating = false;
#         hiding = "dodgewindows";
#         lengthMode = "fit";
#         screen = "all";
#         widgets = [
#           { ## TODO here instead of top? launcher, pager, tray, clock
#             # icons
# #             iconTasks = {
# #               appearance = {
# #                 fill = false;
# #                 highlightWindows = true;
# #                 iconSpacing = "medium";
# #                 indicateAudioStreams = true;
# #                 rows = {
# #                   multirowView = "never";
# #                   maximum = null;
# #                 };
# #                 showTooltips = true;
# #               };
# #               behavior = {
# #                 grouping = {
# #                   clickAction = "showPresentWindowsEffect";
# #                   method = "byProgramName";
# #                 };
# #                 middleClickAction = "newInstance";
# #                 minimizeActiveTaskOnClick = true;
# #                 newTasksAppearOn = "right";
# #                 showTasks = {
# #                   onlyInCurrentActivity = true;
# #                   onlyInCurrentDesktop = true;
# #                   onlyMinimized = false;
# #                   onlyInCurrentScreen = false;
# #                 };
# #                 sortingMethod = "manually";
# #                 unhideOnAttentionNeeded = true;
# #                 wheel = {
# #                   ignoreMinimizedTasks = true;
# #                   switchBetweenTasks = true;
# #                 };
# #               };
# #               launchers = [
# #                 "applications:org.kde.dolphin.desktop"
# #                 "applications:org.kde.konsole.desktop"
# #                 "preferred://browser"
# #               ];
# #             };
#           }
# #           "org.kde.plasma.marginsseparator"
# #           { # music
# #             plasmusicToolbar = {
# #               musicControls = {
# #                 showPlaybackControls = true;
# #                 volumeStep = 1;
# #               };
# #               panelIcon = {
# #                 albumCover = {
# #                   useAsIcon = false;
# #                   radius = 8;
# #                 };
# #                 icon = "view-media-track";
# #               };
# #               songText = {
# #                 displayInSeparateLines = true;
# #                 maximumWidth = 600;
# #                 scrolling = {
# #                   behavior = "alwaysScrollExceptOnHover";
# #                   enable = true;
# #                   resetOnPause = true;
# #                   speed = 3;
# #                 };
# #               };
# #               settings = {
# #                 choosePlayerAutomatically = true;
# #               };
# #             }; # /music
# #           }
#         ];
#       }
      # Top panel
      {
        alignment = "center";
        floating = false;
        height = 26;
        hiding = "none";
        lengthMode = "fill";
        location = "top";
        screen = 0;
        widgets = [
          {
            # launcher
            kickoff = {
              applicationsDisplayMode = "list";
              compactDisplayStyle = false;
              favoritesDisplayMode = "grid";
              icon = "nix-snowflake";
              label = null;
              pin = false;
              showActionButtonCaptions = true;
              showButtonsFor = "power";
              sidebarPosition = "right";
              sortAlphabetically = true;
            };
          }
          {
            # pager
            name = "org.dhruv8sh.kara";
            config = {
              general = {
                animationDuration = 200;
                spacing = 3;
                type = 0;
              };
              type1 = {
                t1activeWidth = 30;
                t1radius = 1;
              };
            };
          }
          { ## icons
            iconTasks = {
              appearance = {
                fill = false;
                highlightWindows = true;
                iconSpacing = "medium";
                indicateAudioStreams = true;
                rows = {
                  multirowView = "never";
                  maximum = null;
                };
                showTooltips = true;
              };
              behavior = {
                grouping = {
                  clickAction = "showPresentWindowsEffect";
                  method = "byProgramName";
                };
                middleClickAction = "newInstance";
                minimizeActiveTaskOnClick = true;
                newTasksAppearOn = "right";
                showTasks = {
                  onlyInCurrentActivity = true;
                  onlyInCurrentDesktop = true;
                  onlyMinimized = false;
                  onlyInCurrentScreen = false;
                };
                sortingMethod = "manually";
                unhideOnAttentionNeeded = true;
                wheel = {
                  ignoreMinimizedTasks = true;
                  switchBetweenTasks = true;
                };
              };
              launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:kitty.desktop"
                "preferred://browser"
              ];
            };
          }
          {
            # title
            applicationTitleBar = {
              behavior = {
                activeTaskSource = "activeTask";
                disableButtonsForNotHovered = false;
                disableForNotMaximized = false;
                filterByActivity = true;
                filterByScreen = true;
                filterByVirtualDesktop = true;
              };
              layout = {
                elements = [ "windowTitle" ];
                fillFreeSpace = false;
                horizontalAlignment = "left";
                showDisabledElements = "deactivated";
                spacingBetweenElements = 0;
                verticalAlignment = "center";
                widgetMargins = 1;
              };
              overrideForMaximized.enable = false;
              windowControlButtons = {
                auroraeTheme = null;
                buttonsAnimationSpeed = 100;
                buttonsAspectRatio = 100;
                buttonsMargin = 0;
                iconSource = "plasma";
              };
              windowTitle = {
                font = {
                  bold = false;
                  fit = "fixedSize";
                  size = 12;
                };
                hideEmptyTitle = true;
                margins = {
                  bottom = 0;
                  left = 10;
                  right = 5;
                  top = 0;
                };
                maximumWidth = 640;
                minimumWidth = 0;
                source = "appName";
                undefinedWindowTitle = "";
              };
            };
          }
          {
            # app menu
            appMenu = {
              compactView = false;
            };
          }
          {
            panelSpacer = {
              expanding = true;
            };
          }
          {
            # tray
            systemTray = {
              icons = {
                scaleToFit = true;
                spacing = "small";
              };
              pin = false;
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
          {
            # clock
            digitalClock = {
              calendar = {
                firstDayOfWeek = "monday";
                plugins = [
                  "astronomicalevents"
                  "holidaysevents"
                ];
                showWeekNumbers = true;
              };
              date = {
                enable = true;
                format = "longDate";
                position = "besideTime";
              };
              font = {
                bold = false;
                family = "Inter";
                italic = false;
                size = 8;
                weight = 400;
              };
              time = {
                format = "24h";
                showSeconds = "onlyInTooltip";
              };
              timeZone = {
                alwaysShow = false;
                changeOnScroll = false;
                lastSelected = "Asia/Ho_Chi_Minh";
                selected = [
                  "Europe/Rome"
                  "Europe/Athens"
                  "Asia/Singapore"
                  "Asia/Ho_Chi_Minh"
                  "America/Cancun"
                ];
              };
            }; # /clock
          }
        ];
      }
    ];
  };
}
