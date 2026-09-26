# Shared Dolphin settings (dolphinrc), used by plasma-manager on Plasma hosts
# and written as a plain file on non-Plasma hosts (nixpad).
# Keys are case-sensitive, see dolphin's share/config.kcfg/dolphin_generalsettings.kcfg
{
  General = {
    # Interface -> Folder and Tabs
    ShowFullPathInTitlebar = true;

    # Interface -> Status and Location Bars
    ShowStatusBar = "Small"; # Small | FullWidth | Disabled
    ShowFullPath = true;
    EditableUrl = true;

    # View -> General -> Browsing
    AutoExpandFolders = true;
    BrowseThroughArchives = true;
    ShowSelectionToggle = true; # selection marker on hover
  };
}
