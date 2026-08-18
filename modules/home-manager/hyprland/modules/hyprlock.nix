{
  config,
  lib,
  ...
}:

let
  cfg = config.local.hyprland;
  fonts = config.local.fonts;
in
{
  config = lib.mkIf cfg.enable {
    # Beginner orientation:
    #
    # hyprlock is the lock screen. It is what you see after pressing SUPER+L or
    # after hypridle locks the session.
    #
    # This block controls the look of the lock screen: background, password
    # input field, time, and date. The composition follows GNOME's shield
    # hierarchy — a bold clock dominating upper-center, the date beneath it,
    # and a lone frosted password field below center (no username label; on a
    # single-user machine it stated the obvious). PAM and session-lock
    # ownership remain entirely with hyprlock.
    #
    # The palette is deliberately neutral: every color here is white, black,
    # or an alpha of them (design-locked 2026-08-17). The frost on the input
    # field needs no compositor tricks — the background below is already
    # blurred, so a low-alpha white fill over it IS the glass.
    #
    # Source: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
    programs.hyprlock = {
      enable = true;

      settings = {
        general = {
          # Hide the mouse cursor while locked.
          hide_cursor = true;
          immediate_render = true;

          # hyprlock defaults to two seconds, which is easy to miss while the
          # field transitions back to its placeholder. Keep failures visible
          # long enough to read without leaving stale auth state on screen.
          fail_timeout = 5000;
        };

        background = [
          {
            # The wallpaper is a Nix-owned stable path shared with the rest of
            # the Hyprland session (see local.hyprland.wallpaper in
            # default.nix). A stable Home Manager link makes this work in a
            # clean VM and avoids capturing readable window contents at lock
            # time. The solid color is shown while immediate rendering loads
            # the image, and remains as the fallback if the path is unreadable.
            path = cfg.wallpaper;

            # Blur keeps the wallpaper recognizable. The stronger brightness
            # reduction is also a contrast boundary: every possible image is
            # darkened before white text is composited, instead of relying on
            # the current wallpaper happening to be dark behind each label.
            blur_passes = 3;
            blur_size = 8;
            brightness = 0.42;
            contrast = 0.9;
            vibrancy = 0.2;
            vibrancy_darkness = 0.2;

            color = "rgb(000000)";
          }
        ];

        input-field = [
          {
            # Empty monitor means "show this on all monitors".
            monitor = "";

            # Just below center, closing toward the clock so the whole
            # composition reads as one centered cluster rather than a clock
            # zone and an auth zone (positions live-tuned with hyprlock -c).
            size = "380, 56";
            position = "0, -115";
            halign = "center";
            valign = "center";

            # Borderless frost: the background above is pre-blurred, so this
            # low-alpha white lift over it reads as translucent glass. More
            # alpha was tried and rejected — white over a darkened backdrop
            # goes flat gray fast. hyprlock has no placeholder alignment
            # option, so the placeholder stays centered.
            outline_thickness = 0;
            inner_color = "rgba(ffffff30)";
            font_color = "rgba(ffffffff)";
            # Auth states keep the neutral palette; fail_text is the failure
            # signal rather than a color change. In borderless mode hyprlock
            # has no outline to recolor, so it pours check/fail_color into the
            # inner box instead -- opaque white flooded the frost on every
            # failed attempt. swap_font_color reroutes those state colors to
            # the font, where white is what the field renders anyway, leaving
            # the glass untouched (PasswordInputField.cpp's BORDERLESS path).
            swap_font_color = true;
            check_color = "rgba(ffffffff)";
            fail_color = "rgba(ffffffff)";
            font_family = fonts.shell.family;

            # Password dots are centered in the input field.
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Enter Password";
            check_text = "Authenticating...";
            # $FAIL is hyprlock's backend-agnostic failure message. $PAMFAIL
            # can be empty when no PAM-specific string accompanies a failure.
            fail_text = "$FAIL";
            # Rounded rectangle, not a pill, matching the shell's capsule
            # doctrine.
            rounding = 12;
            shadow_passes = 2;
            shadow_size = 4;
            shadow_color = "rgba(000000cc)";
          }
        ];

        label = [
          {
            # GNOME's shield leads with the time: large and bold, riding above
            # center. The bold face is requested by family name because
            # hyprlock labels have no weight option.
            monitor = "";
            text = "$TIME";
            color = "rgba(ffffffff)";
            font_size = 150;
            font_family = "${fonts.shell.family} Bold";
            position = "0, 165";
            halign = "center";
            valign = "center";
            shadow_passes = 4;
            shadow_size = 6;
            shadow_color = "rgba(000000e6)";
          }
          {
            # The date sits beneath the clock, GNOME-style. GNU date's %-d
            # omits the leading zero from single-digit days.
            monitor = "";
            text = "cmd[update:60000] date '+%A, %B %-d'";
            color = "rgba(ffffffe6)";
            font_size = 26;
            font_family = fonts.shell.family;
            position = "0, 25";
            halign = "center";
            valign = "center";
            shadow_passes = 4;
            shadow_size = 5;
            shadow_color = "rgba(000000e6)";
          }
        ];
      };
    };
  };
}
