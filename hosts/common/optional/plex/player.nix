# TODO fix this mess: here i just enable flatpak and then install it imperatively...
{
    services.flatpak = {
        enable = true;
    };
}
# then, imperatively:
# flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# flatpak install flathub tv.plex.PlexDesktop
# flatpak run tv.plex.PlexDesktop