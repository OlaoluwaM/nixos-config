{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.hyprland;
  antiburnPackage = pkgs.callPackage ../../../../pkgs/antiburn { };
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      # Startup Antiburn at login. Doing so from the app won't persist across logins like it should.
      antiburn = {
        Unit = {
          Description = "Antiburn session usage monitor";
          PartOf = [ config.wayland.systemd.target ];
          After = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          ExecStart = "${lib.getExe antiburnPackage} --background";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # Watch PipeWire, the desktop's audio and video system. While media is playing, ask hypridle, the idle timer, to leave the session (Hyprland) unlocked. Restart the watcher if it fails.
      hypr-shell-media-idle-inhibit = {
        Unit = {
          Description = "Inhibit idle while PipeWire media is playing";
          PartOf = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit";
          Restart = "on-failure";
        };
      };

      # Caffeine keeps the session from going idle until you turn it off.
      # systemd-inhibit holds that request while "sleep infinity" runs;
      # stopping the service releases it, so hypridle can act again.
      # commands.nix packages the helper that starts and stops this service.
      # It also stops with the Hyprland session, so it cannot outlive logout.
      hypr-shell-caffeine = {
        Unit = {
          Description = "Manual Hyprland idle inhibitor";
          PartOf = [ config.wayland.systemd.target ];
        };

        Service = {
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block ${pkgs.coreutils}/bin/sleep infinity";
        };
      };

      # Start KDE Connect's tray icon when you log into Hyprland.
      kdeconnect-indicator = {
        Unit = {
          Description = "KDE Connect tray indicator";
          PartOf = [ config.wayland.systemd.target ];
          After = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
          Restart = "on-failure";
        };
      };
    };
  };
}
