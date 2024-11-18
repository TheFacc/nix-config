Home-manager configurations: user-level preferences. (dotfiles)
One folder for each user.
In each folder, a nix file for each hosts the user will be present in. This means that a user will have different configuration based on the hosts it's in.

Directories:
- core: personal stuff for THIS user that should be present in ALL systems, eg. env variables, fonts, personal git configs, primary editor settings, personal shell configurations. Stuff that THIS user should always have.
- optional: personal stuff for THIS user that you may not want on all systems, eg. window manager, spotify, telegram...

Example with a main user on two hosts and a media user on 1 host:
- main user will reference all core + most optional stuff
- media user will reference all core + some (if any) optional stuff