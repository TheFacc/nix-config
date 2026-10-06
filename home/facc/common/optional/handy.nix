# Handy: offline push-to-talk speech-to-text (https://github.com/cjpais/Handy)
{ lib, pkgs, ... }:
let
  # On Wayland Handy types the transcription through wtype; without it, it
  # falls back to enigo, which barely works there.
  handy = pkgs.symlinkJoin {
    name = "handy-wayland";
    paths = [ pkgs.handy ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/handy --prefix PATH : ${lib.makeBinPath [ pkgs.wtype ]}
    '';
    inherit (pkgs.handy) meta;
  };
in
{
  home.packages = [ handy ];

  # Wayland gives apps no global shortcuts: keep Handy running in the tray and
  # let the compositor bind `handy --toggle-transcription` (see niri binds).
  systemd.user.services.handy = {
    Unit = {
      Description = "Handy speech-to-text";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${handy}/bin/handy --start-hidden";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
