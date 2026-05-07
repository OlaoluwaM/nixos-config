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
            path = "screenshot";
            blur_passes = 2;
            blur_size = 7;
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "240, 50";
            position = "0, -80";
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = "Password...";
          }
        ];
      };
    };
  };
}
