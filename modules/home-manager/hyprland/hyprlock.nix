{
  config,
  lib,
  ...
}:

let
  cfg = config.local.hyprland;
  theme = config.local.theme.colors;
  stripHash = s: lib.removePrefix "#" s;
in
{
  config = lib.mkIf cfg.enable {
    # Beginner orientation:
    #
    # hyprlock is the lock screen. It is what you see after pressing SUPER+L or
    # after hypridle locks the session.
    #
    # This block controls the look of the lock screen: background, password
    # input field, time label, and date label.
    #
    # Source: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
    programs.hyprlock = {
      enable = true;

      settings = {
        general = {
          # Hide the mouse cursor while locked.
          hide_cursor = true;
        };

        background = [
          {
            # Waypaper updates this symlink after a wallpaper is selected.
            # hyprlock uses the symlink as the lock-screen background.
            path = "${config.xdg.cacheHome}/hypr-shell/lock-wallpaper";

            # Blur makes the wallpaper less visually noisy behind the password
            # field. Higher values are stronger but may be heavier to render.
            blur_passes = 3;
            blur_size = 8;

            # Fallback background color if the wallpaper path cannot be read.
            color = "rgb(${stripHash theme.lockFallbackBg})";
          }
        ];

        input-field = [
          {
            # Empty monitor means "show this on all monitors".
            monitor = "";

            # Password box size and position. Position is an offset from the
            # alignment point. Here it is centered horizontally and shifted down.
            size = "280, 54";
            position = "0, -70";

            outline_thickness = 2;
            outer_color = "rgb(${stripHash theme.lockOuterColor})";
            inner_color = "rgb(${stripHash theme.lockInnerColor})";
            font_color = "rgb(${stripHash theme.lockFontColor})";
            check_color = "rgb(${stripHash theme.lockCheckColor})";
            fail_color = "rgb(${stripHash theme.lockFailColor})";

            # Password dots are centered in the input field.
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Password";
            rounding = 10;
            shadow_passes = 2;
          }
        ];

        label = [
          {
            # Large clock label. hyprlock substitutes $TIME itself.
            monitor = "";
            text = "$TIME";
            color = "rgb(${stripHash theme.lockClockColor})";
            font_size = 64;
            font_family = "sans-serif";
            position = "0, 90";
            halign = "center";
            valign = "center";
          }
          {
            # Smaller date label. cmd[update:30000] means hyprlock runs the date
            # command every 30 seconds and uses the output as label text.
            monitor = "";
            text = "cmd[update:30000] date '+%A, %B %d'";
            color = "rgb(${stripHash theme.lockDateColor})";
            font_size = 18;
            font_family = "sans-serif";
            position = "0, 35";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };
  };
}
