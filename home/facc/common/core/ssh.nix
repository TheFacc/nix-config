{ lib, pkgs, ... } @ args:
let
  # gnome-keyring's agent: lists every ~/.ssh key, asks each passphrase once
  # ("unlock when logged in") and keeps it in the login keyring, which PAM
  # opens at login. So agents and other non-interactive git get the keys.
  gcr = (args.osConfig or null).services.gnome.gcr-ssh-agent.enable or false;
in
{
  # One agent for shells and desktop apps on every host. Without gcr, unlock
  # the keys after login with: ssh-add ~/.ssh/id_facc ~/.ssh/id_becq
  services.ssh-agent.enable = !gcr;
  sshAuthSock = lib.mkIf gcr {
    enable = true;
    initialization.bash = ''export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"'';
    systemd.socketProviderUnit = "gcr-ssh-agent.socket";
  };

  # ~/.ssh/config is a nix-store symlink; in user namespaces (AppImages via
  # bwrap, agent sandboxes) root is unmapped, it looks nobody-owned and ssh
  # rejects it. The owner check only applies to the implicit config, not -F.
  # A PATH wrapper (not a shell alias) so subprocesses like T3 Code get it too;
  # ssh keeps the last -F, so an explicit -F still wins.
  home.packages = [
    (lib.hiPrio (pkgs.writeShellScriptBin "ssh" ''
      if [ -e "$HOME/.ssh/config" ]; then
        exec ${pkgs.openssh}/bin/ssh -F "$HOME/.ssh/config" "$@"
      fi
      exec ${pkgs.openssh}/bin/ssh "$@"
    ''))
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      # GitHub keys are picked per directory in git.nix (core.sshCommand).

      # lux
      # "*.google.com" = {
      #   HostName = "source.developers.google.com";
      #   User = "alessio.facincani@ext.luxottica.com";
      #   IdentityFile = "~/.ssh/id_rsa_lux";
      # };
    };
  };
  #  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
