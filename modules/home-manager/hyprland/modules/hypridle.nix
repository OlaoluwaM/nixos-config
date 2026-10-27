{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.hyprland;
  dpms = action: "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"${action}\" })'";
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
          # lock, including loginctl lock-session from idle, Super+L and
          # suspend (the shell menu runs the wrapper itself; see lockCommand
          # in silere.nix). Every request runs the silere-lock wrapper
          # (commands.nix), and the wrapper decides: it moves the lock into a
          # scope of its own so a hypridle restart cannot kill it, skips the
          # request when a lock is already up, and otherwise starts the lock
          # local.hyprland.lockScreen picks: the hyprlock the profile themes
          # (config.programs.hyprlock.package), or silere-shell's own lock
          # with that hyprlock as its fallback. It has to decide, rather than
          # leave duplicates to Hyprland, because
          # misc:allow_session_lock_restore (compositor.nix) lets a second
          # client take over a lock.
          lock_cmd = lib.getExe cfg.commands.lockScript;

          # before_sleep_cmd runs before suspend/sleep. Lock the session, then
          # power off the displays before the machine enters suspend. This
          # gives lid-close the same immediate blanking step as idle display
          # timeout instead of waiting for the kernel to enter the sleep state.
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session && ${dpms "disable"}";

          # after_sleep_cmd runs after resume. DPMS is the display power
          # management signal; this makes sure screens are powered on again.
          after_sleep_cmd = dpms "enable";

          # Wait until the session is locked before allowing suspend to
          # continue.
          #
          # 3 ("wait until locked"), because 2 ("auto") no longer picks that
          # path here: auto only waits for lock-notify when lock_cmd mentions
          # hyprlock, and lock_cmd is the silere-lock wrapper. Hyprland
          # sends lock-notify for any session-lock client, so the wait holds
          # for hyprlock and the shell's lock alike, and the session becoming
          # locked releases the inhibitor. The cost: hypridle's `case 3` has
          # no else branch, so on a compositor without
          # hyprland-lock-notify-v1 it takes no sleep inhibitor at all. That
          # is not this profile; Hyprland 0.55.4 has the protocol.
          #
          # The inhibitor is a logind delay inhibitor, capped by logind's
          # InhibitDelayMaxSec (raised in modules/nixos/hyprland.nix).
          inhibit_sleep = 3;

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
            on-timeout = dpms "disable";
            on-resume = dpms "enable";
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
