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
    services.hypridle = {
      enable = true;

      settings = {
        general = {
          lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
        };

        listener = [
          {
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
