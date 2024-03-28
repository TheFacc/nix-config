# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix # XPS 9570 default config
      ./xps9560/dell/xps/15-9560 # Intel+Nvidia config from https://github.com/NixOS/nixos-hardware/tree/master/dell/xps/15-9560 (working on 9570)
    #  ./variables.nix
       ./home-manager.nix # User config
       ./audio.nix # all audio config
       ./onedrive.nix # OneDrive sync
       ./syncthing.nix # Syncthing sync
       ./vscode.nix # VSCode app and extensions
       ./vpn.nix # VPN / Wireguard
#       ./steam.nix # Steam
       ./vm.nix # Virtual machine
       ./docker.nix # lato oscuro
       ./orbslam3.nix # keep opencv+gtk2 in the system to prevent its deletion+rebuild every time
       ./matlab.nix
       ./sonarr.nix # Sonarr
       ./plex.nix # Plex player
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # NTFS support
  boot.supportedFilesystems = ["ntfs"];

  # Force Nix to be stable (https://discourse.nixos.org/t/sudo-nixos-rebuild-switch-upgrade-does-not-get-updates-anymore/27072/9)
#  nix.package = pkgs.nixStable;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable bluetooth
  hardware.bluetooth.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Basic touchpad preferences
  services.xserver.libinput.touchpad = {
    naturalScrolling = true;
    tappingDragLock = false;
  };

  # Configure keymap in X11
  services.xserver = {
    layout = "it";
    xkbVariant = "";
  };

  # Configure console keymap
  console.keyMap = "it2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # enable core dumps - https://github.com/NixOS/nixpkgs/issues/60088
  systemd.coredump.enable = true;
  #systemd.coredump.extraConfig = "Storage=/home/facc/core";

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.facc = {
    isNormalUser = true;
    description = "facc";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      # TOOLS:
      wget
      unrar
      xarchiver
#      git #--> in home-manager.nix
      #baobab
      #gparted
      #anydesk
      # WRITE:
      kate
#      emacs
#      vscode #--> in vscode.nix with extensions
      zotero
      # BROWSERS:
      brave
      firefox
      google-chrome
      # SYNC:
      rclone
#      syncthing #--> in syncthing.nix
#      onedrive #--> in onedrive.nix
#      qbittorrent #--> in sonarr.nix
      # SOCIAL:
      tdesktop
#      beeper
      # ENTERTAINMENT:
      vlc
#      plex-media-player #--> plex.nix
#      audacity #--> in audio.nix
#      pulseaudio #--> in audio.nix
    ];
  };

  # Allow various unfree packages (nvidia)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  # List packages installed in system profile. To search, run: nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];

  # Fonts
  fonts.packages = with pkgs; [
    iosevka
    inter
    lato
    inconsolata
    liberation_ttf
    fira
    fira-code
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Kill process eating RAM to prevent system hang
  services.earlyoom.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

}
