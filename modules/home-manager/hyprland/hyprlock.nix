{
  config,
  lib,
  ...
}:

let
  cfg = config.local.hyprland;
  theme = config.local.theme.colors;
  fonts = config.local.fonts;
  stripHash = s: lib.removePrefix "#" s;
in
{
  config = lib.mkIf cfg.enable {
    # Only theme the lock screen through the Catppuccin port when that preset is
    # active, and never let it source its example layout: the explicit
    # background/input-field/label blocks below already define every widget, so
    # useDefaultConfig would append a second, duplicate set of them.
    catppuccin.hyprlock = {
      enable = config.local.catppuccin.enable;
      useDefaultConfig = false;
    };
    # Beginner orientation:
    #
    # hyprlock is the lock screen. It is what you see after pressing SUPER+L or
    # after hypridle locks the session.
    #
    # This block controls the look of the lock screen: background, clock
    # surface, password input field, time label, and date label. Its visual
    # choices deliberately mirror Caffyne's native lock screen, while PAM and
    # session-lock ownership remain entirely with hyprlock.
    #
    # Source: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
    programs.hyprlock = {
      enable = true;

      settings = {
        general = {
          # Hide the mouse cursor while locked.
          hide_cursor = true;
          immediate_render = true;
        };

        background = [
          {
            # Use the same Nix-owned wallpaper that is written into Caffyne's
            # durable config. A stable Home Manager link makes this work in a
            # clean VM and avoids capturing readable window contents at lock
            # time. The solid color is shown while immediate rendering loads
            # the image, and remains as the fallback if the path is unreadable.
            path = cfg.wallpaper;

            # Blur and darkening keep the wallpaper recognizable without
            # competing with the clock and authentication field. These values
            # are intentionally modest enough for a VM's virtual GPU.
            blur_passes = 3;
            blur_size = 8;
            brightness = 0.68;
            contrast = 0.9;
            vibrancy = 0.2;
            vibrancy_darkness = 0.2;

            color = "rgb(${stripHash theme.lockBackground})";
          }
        ];

        shape = [
          {
            # Caffyne places its clock on a circular surface with a fine
            # outline. Negative rounding tells hyprlock to make a circle.
            # zindex keeps this surface behind the time label below.
            monitor = "";
            size = "180, 180";
            position = "0, 105";
            halign = "center";
            valign = "center";
            zindex = 0;

            color = "rgba(${stripHash theme.lockInputColor}e6)";
            rounding = -1;
            border_size = 1;
            border_color = "rgba(${stripHash theme.lockRingColor}66)";
            shadow_passes = 2;
            shadow_size = 6;
            shadow_color = "rgba(00000066)";
          }
        ];

        input-field = [
          {
            # Empty monitor means "show this on all monitors".
            monitor = "";

            # Password box size and position. Position is an offset from the
            # alignment point. Here it is centered horizontally and shifted down.
            size = "318, 56";
            position = "0, -88";

            outline_thickness = 2;
            outer_color = "rgb(${stripHash theme.lockRingColor})";
            inner_color = "rgb(${stripHash theme.lockInputColor})";
            font_color = "rgb(${stripHash theme.lockTextColor})";
            check_color = "rgb(${stripHash theme.lockCheckColor})";
            fail_color = "rgb(${stripHash theme.lockFailColor})";
            font_family = fonts.shell.family;

            # Password dots are centered in the input field.
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Password";
            check_text = "Authenticating...";
            fail_text = "$PAMFAIL";
            rounding = 10;
            shadow_passes = 2;
          }
        ];

        label = [
          {
            # Caffyne uses a compact clock inside its circular surface.
            # hyprlock substitutes $TIME itself, so no helper process is needed.
            monitor = "";
            text = "$TIME";
            color = "rgb(${stripHash theme.lockClockColor})";
            font_size = 36;
            font_family = fonts.shell.family;
            position = "0, 105";
            halign = "center";
            valign = "center";
            zindex = 1;
          }
          {
            # Keep the date outside the clock surface as the quiet secondary
            # label. The command is refreshed once a minute while locked.
            monitor = "";
            text = "cmd[update:60000] date '+%A, %B %d'";
            color = "rgb(${stripHash theme.lockDateColor})";
            font_size = 18;
            font_family = fonts.shell.family;
            position = "0, -15";
            halign = "center";
            valign = "center";
            zindex = 1;
          }
        ];
      };
    };
  };
}
