This folder contains all the host-level configurations, all the system specific settings for each distinct system controlled by the configuration.

Define specific host packages and which users to create.

For example, dev modules will only be present in your main machine (host nix file), while you may want the browser/shell/wm config to be consistent among all machines (/common directory)

Each user file ./hosts/common/$USER.nix will reference a ./home/$USER/$HOST.nix config file.

In the common directory, there will be:
- subdirectories for each user: defining how each user should be configured on that machine, eg their passwords, secrets, and what home-manager configurations to reference from the home section.
- core: any non-user system level settings that are present or required on all of the hosts in my network, eg. localization, nixos stuff like gc, services like ssh, sops for secrets, basic shell settings...
- optional: other system-level configs that might not need to be present in all systems, eg. browser, window manager, streaming tools, pipewire, steam, vlc...

Important note: make no exceptions, core stuff is stuff that must be present in ANY machine for ANY user. Optional stuff is optional. If you find later that some you don't want some core module in a machine, move it to optional. Or vv.

Example with one main host and one media host:
- main host will have the main user, all core, and some optional.
- media host will have main+media user, all core, and some (less) optional.