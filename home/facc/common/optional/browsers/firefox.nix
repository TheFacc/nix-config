{ pkgs, inputs, ... }:
{ # example: https://pastebin.com/fBnPupGy
  programs.firefox = {
    enable = true;
    profiles."facc" = {
      # enable = true;
      bookmarks = [
        { #TODO: add more bookmarks
        		name = "Bookmarks Toolbar";
						toolbar = true;
            bookmarks = [
              {
                name = "Sonarr";
                url = "localhost:8989";
                tags = [ "arr" ];
              }
            ];
          }
      ];
      settings = { # about:config
        "browser.shell.checkDefaultBrowser" = false;
        "browser.startup.homepage" = "https://start.duckduckgo.com";
        "browser.startup.page" = 0;
        "browser.tabs.closeWindowWithLastTab" = true;
        "browser.download.panel.shown" = true;
        "browser.download.useDownloadDir" = false;
        # "signon.rememberSignons" = false;
        "general.smoothScroll" = true;
      };
      search = {
        force = true;
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            # icon = "https://search.nixos.org/favicon.ico";
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };
          "DuckDuckGo" = {
            urls = [{
              template = "https://duckduckgo.com/";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            icon = "https://duckduckgo.com/favicon.ico";
            definedAliases = [ "@ddg" ];
          };
          "Google" = {
            urls = [{
              template = "https://www.google.com/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            icon = "https://www.google.com/favicon.ico";
            definedAliases = [ "@g" ];
          };
          "YouTube" = {
            urls = [{
              template = "https://www.youtube.com/results";
              params = [
                { name = "search_query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "https://www.youtube.com/favicon.ico";
            definedAliases = [ "@yt" ];
          };
          "Wikipedia" = {
            urls = [{
              template = "https://en.wikipedia.org/wiki/Special:Search";
              params = [
                { name = "search"; value = "{searchTerms}"; }
              ];
            }];
            icon = "https://en.wikipedia.org/favicon.ico";
            definedAliases = [ "@w" ];
          };
        };
        privateDefault = "DuckDuckGo";
      };
      userChrome = ''
        /* some css */
      '';
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [ #TODO inherit system
          ublock-origin
        ];
    };

    # commandLineArgs = [
    #   "--no-default-browser-check"
    #   "--restore-last-session"
    # ];
  };
}
