{ config, pkgs, ... }:

{
  users.users.facc = {
    extraGroups = [ "audio" ];
    packages = with pkgs; [
      audacity
      pavucontrol
    ];
  };
  sound.enable = true;
  security.rtkit.enable = true;

  # Option 1 (default): Enable sound with pipewire sound server.
#  hardware.pulseaudio.enable = false;
#  services.pipewire = {
#    enable = true;
#    alsa.enable = true;
#    alsa.support32Bit = true;
#    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
#  };

  # Option 2: Enable sound with PulseAudio sound server
  hardware.pulseaudio.package = pkgs.pulseaudioFull;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.enableAllFirmware = true;
  nixpkgs.config.pulseaudio = true;
}
