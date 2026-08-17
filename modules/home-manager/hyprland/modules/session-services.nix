{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    # Extra Hyprland-session user services that do not have dedicated Home
    # Manager modules in this config.
    systemd.user.services = {
      # Block idle while PipeWire reports active media playback, so videos,
      # calls, and similar media do not let hypridle lock the session.
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

      # Manual Caffeine is shared session infrastructure; hypridle respects
      # its systemd idle inhibitor. The toggle helper users actually invoke
      # (the caffeineScript writeShellApplication) lives in commands.nix --
      # two halves of one feature, split along the module axis deliberately:
      # this file owns the always-on inhibitor unit, commands.nix owns the
      # packaged command that flips it.
      hypr-shell-caffeine = {
        Unit = {
          Description = "Manual Hyprland idle inhibitor";
          PartOf = [ config.wayland.systemd.target ];
        };

        Service = {
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block ${pkgs.coreutils}/bin/sleep infinity";
        };
      };

      # KDE Connect's session half. The package + firewall ports come from
      # programs.kdeconnect in modules/nixos/hyprland.nix; GNOME/KDE would
      # autostart the indicator via XDG autostart, which nothing in this
      # profile processes, so it gets an explicit unit on the session target
      # instead. The indicator D-Bus-activates kdeconnectd itself and
      # registers the SNI item the shell's tray popup lists.
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
