{
  config,
  lib,
  ...
}:

let
  cfg = config.local.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    programs.hyprlock = {
      enable = true;

      settings = {
        general = {
          hide_cursor = true;
        };

        background = [
          {
            path = "${config.xdg.cacheHome}/hypr-shell/lock-wallpaper";
            blur_passes = 3;
            blur_size = 8;
            color = "rgb(11111b)";
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "280, 54";
            position = "0, -70";
            outline_thickness = 2;
            outer_color = "rgb(cba6f7)";
            inner_color = "rgb(181825)";
            font_color = "rgb(cdd6f4)";
            check_color = "rgb(89b4fa)";
            fail_color = "rgb(f38ba8)";
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Password";
            rounding = 10;
            shadow_passes = 2;
          }
        ];

        label = [
          {
            monitor = "";
            text = "$TIME";
            color = "rgb(f5e0dc)";
            font_size = 64;
            font_family = "sans-serif";
            position = "0, 90";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "cmd[update:30000] date '+%A, %B %d'";
            color = "rgb(cdd6f4)";
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
