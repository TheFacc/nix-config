{ pkgs, ... }:
{
    # https://nixos.wiki/wiki/IOS
    services.usbmuxd.enable = true;
    environment.systemPackages = with pkgs; [
        libimobiledevice
        # ifuse # optional, to mount using 'ifuse'
    ];
}