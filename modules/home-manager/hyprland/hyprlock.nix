{
  config,
  lib,
  ...
}:

let
  cfg = config.local.hyprland;
  fonts = config.local.fonts;
  theme = config.local.theme.colors;
  stripHash = lib.removePrefix "#";
in
{
  config = lib.mkIf cfg.enable {
    # Keep Catppuccin from injecting accent variables or its example layout.
    # This lock screen deliberately uses only neutral white, translucent white,
    # and black so the wallpaper supplies all visible color.
    catppuccin.hyprlock.enable = false;
    # Beginner orientation:
    #
    # hyprlock is the lock screen. It is what you see after pressing SUPER+L or
    # after hypridle locks the session.
    #
    # This block controls the look of the lock screen: background, password
    # input field, time, date, and username. The composition borrows macOS's
    # quiet hierarchy and neutral glass treatment. PAM and session-lock
    # ownership remain entirely with hyprlock.
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
            # Use the same Nix-owned wallpaper that is written into Caffyne's
            # durable config. A stable Home Manager link makes this work in a
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

            # Anchor the compact password field to the bottom rather than the
            # display center. This keeps the clock visually dominant and makes
            # the composition adapt to the VM and laptop display heights.
            size = "240, 40";
            position = "0, 100";
            halign = "center";
            valign = "bottom";

            # The background's brightness cap supplies the contrast boundary,
            # so this field only needs a light neutral tint rather than an
            # opaque black fill. Auth states vary opacity instead of hue;
            # fail_text remains the clear signal when color is absent.
            outline_thickness = 1;
            outer_color = "rgba(ffffff66)";
            inner_color = "rgba(00000033)";
            font_color = "rgba(ffffffff)";
            # Hyprlock replaces font_color with these colors while checking or
            # reporting a failure. Caffyne calls this semantic role
            # `on_surface`; local.theme.colors.text is the shared Nix token.
            check_color = "rgb(${stripHash theme.text})";
            fail_color = "rgb(${stripHash theme.text})";
            font_family = fonts.shell.family;

            # Password dots are centered in the input field.
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Enter Password";
            check_text = "Authenticating...";
            # $FAIL is hyprlock's backend-agnostic failure message. $PAMFAIL
            # can be empty when no PAM-specific string accompanies a failure.
            fail_text = "$FAIL";
            # Ten pixels reads as a rounded rectangle rather than a pill while
            # preserving the soft geometry used elsewhere in the lock screen.
            rounding = 10;
            shadow_passes = 2;
            shadow_size = 4;
            shadow_color = "rgba(000000cc)";
          }
        ];

        label = [
          {
            # The date sits above the clock, following the reference hierarchy.
            # GNU date's %-d omits the leading zero from single-digit days.
            monitor = "";
            text = "cmd[update:60000] date '+%A, %B %-d'";
            color = "rgba(ffffffe6)";
            font_size = 20;
            font_family = fonts.shell.family;
            position = "0, -75";
            halign = "center";
            valign = "top";
            shadow_passes = 4;
            shadow_size = 5;
            shadow_color = "rgba(000000e6)";
          }
          {
            # hyprlock substitutes $TIME without spawning a helper. Keep this
            # as the largest element, but leave enough top margin for laptop
            # panels with a camera notch or thick bezel.
            monitor = "";
            text = "$TIME";
            color = "rgba(ffffffff)";
            font_size = 84;
            font_family = fonts.shell.family;
            position = "0, -115";
            halign = "center";
            valign = "top";
            shadow_passes = 4;
            shadow_size = 6;
            shadow_color = "rgba(000000e6)";
          }
          {
            # An AccountsService avatar is not provisioned by this repo, so a
            # username label is deterministic in a clean VM while still giving
            # the lower authentication area a clear identity.
            monitor = "";
            text = "$USER";
            color = "rgba(fffffff2)";
            font_size = 16;
            font_family = fonts.shell.family;
            position = "0, 160";
            halign = "center";
            valign = "bottom";
            shadow_passes = 4;
            shadow_size = 5;
            shadow_color = "rgba(000000e6)";
          }
        ];
      };
    };
  };
}
