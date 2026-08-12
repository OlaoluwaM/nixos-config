{ config, lib, ... }:

let
  cfg = config.local.gnome;
  uint32 = lib.hm.gvariant.mkUint32;
in
{
  config = lib.mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        enable-animations = true;
        enable-hot-corners = false;
        font-antialiasing = "rgba";
        font-hinting = "medium";
        toolkit-accessibility = false;
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        click-method = "fingers";
        two-finger-scrolling-enabled = true;
      };

      "org/gnome/desktop/notifications" = {
        show-banners = false;
      };

      "org/gnome/desktop/privacy" = {
        report-technical-problems = true;
      };

      "org/gnome/desktop/datetime" = {
        automatic-timezone = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        action-double-click-titlebar = "toggle-maximize";
        action-middle-click-titlebar = "none";
        action-right-click-titlebar = "menu";
        button-layout = "appmenu:minimize,maximize,close";
        focus-mode = "click";
        resize-with-right-button = true;
        workspace-names = [
          "Study"
          "Dev"
          "Content"
          "Job Search"
        ];
      };

      "org/gnome/mutter" = {
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
        ];
      };

      "org/gnome/system/location" = {
        enabled = true;
      };

      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = false;
        night-light-schedule-from = 19.0;
        night-light-schedule-to = 8.0;
        night-light-temperature = uint32 2467;
      };
    };
  };
}
