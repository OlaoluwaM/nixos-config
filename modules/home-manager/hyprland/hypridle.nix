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
    # Beginner orientation:
    #
    # hypridle is Hyprland's idle manager. "Idle" means the system has not seen
    # keyboard/mouse activity for a while. hypridle can react by locking the
    # session, turning displays off, suspending, etc.
    #
    # This Home Manager block generates the hypridle config and enables the
    # user service.
    #
    # Source: https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
    services.hypridle = {
      enable = true;

      settings = {
        general = {
          # lock_cmd is what hypridle runs when something asks the session to
          # lock, including loginctl lock-session. pidof hyprlock prevents
          # launching another hyprlock if one is already running.
          lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";

          # before_sleep_cmd runs before suspend/sleep. Locking before sleep
          # means the machine should ask for a password after waking.
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";

          # after_sleep_cmd runs after resume. DPMS is the display power
          # management signal; this tries to make sure screens are powered on.
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";

          # Wait until the lock screen reports that the session is locked before
          # allowing suspend to continue.
          inhibit_sleep = 3;
        };

        listener = [
          {
            # After 900 seconds of inactivity, ask systemd/loginctl to lock the
            # session. That flows back into lock_cmd above.
            timeout = 900;
            on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
          }
          # VM displays can fail to wake cleanly after DPMS off. Re-enable this
          # on bare metal if display-off idle behavior is still wanted.
          # {
          #   timeout = 1200;
          #   on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
          #   on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          # }
        ];
      };
    };
  };
}
