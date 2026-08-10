{
  config,
  lib,
  pkgs,
  unstable,
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

      # NixOS 26.05 still packages hypridle 0.1.7. Use 0.1.8 from the
      # repository's existing unstable package set because upstream 0.1.8
      # fixes D-Bus inhibitor cookie/count accounting when one owner exits
      # while holding multiple cookies. Keeping D-Bus inhibition enabled then
      # remains safe without carrying a local downstream source patch.
      package = unstable.hypridle;

      settings = {
        general = {
          # lock_cmd is what hypridle runs when something asks the session to
          # lock, including loginctl lock-session. Run hyprlock for every
          # request so a terminating or unrelated process cannot hide a fresh
          # lock request. Hyprland rejects duplicate session-lock clients while
          # preserving the valid lock client.
          #
          # Use the same hyprlock the profile installs and themes
          # (config.programs.hyprlock.package, set in hyprlock.nix) instead of
          # pkgs.hyprlock directly. Both resolve to the same package today,
          # but pkgs.hyprlock would silently drift from whatever this profile
          # actually configures if that ever changes.
          lock_cmd = "${config.programs.hyprlock.package}/bin/hyprlock";

          # before_sleep_cmd runs before suspend/sleep. Locking before sleep
          # means the machine should ask for a password after waking.
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";

          # after_sleep_cmd runs after resume. DPMS is the display power
          # management signal; this tries to make sure screens are powered on.
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";

          # Wait until the lock screen reports that the session is locked before
          # allowing suspend to continue.
          #
          # 2 ("auto"), not 3 ("wait until locked"), deliberately. Both pick
          # hypridle's lock-notify path for this exact pair of commands: auto
          # selects it when lock_cmd mentions hyprlock and before_sleep_cmd
          # mentions lock-session, which is what we generate below. The
          # difference is the failure mode. hypridle's `case 3` only assigns a
          # behaviour when the compositor advertises hyprland-lock-notify-v1
          # and has no else branch, so on a compositor without that protocol it
          # falls through to "no sleep inhibitor at all" and the machine can
          # suspend before hyprlock is up. `case 2` falls back to a normal
          # logind delay inhibitor instead. Same behaviour today on Hyprland
          # 0.55.4, safer if the protocol ever goes away.
          inhibit_sleep = 2;

          # Keep hypridle wired into the inhibitor mechanisms used by browsers,
          # media players, wayland-pipewire-idle-inhibit, and the manual
          # shared Caffeine toggle.
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
          ignore_wayland_inhibit = false;
        };

        listener = [
          {
            # After 600 seconds of inactivity, ask systemd/loginctl to lock the
            # session. That flows back into lock_cmd above.
            timeout = 600;
            on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
          }
          {
            timeout = 660;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
          {
            timeout = 900;
            on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
          }
        ];
      };
    };
  };
}
