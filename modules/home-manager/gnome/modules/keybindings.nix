{ config, lib, ... }:

let
  cfg = config.local.gnome;
  enableAsusRogKeybindings = config.local.capabilities.input.asusRogKeys;
  gvariant = lib.hm.gvariant;
  emptyStringArray = gvariant.mkEmptyArray gvariant.type.string;
  customKeybindingSchema = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
  # Used in the media-keys custom-keybindings list, which expects slash-wrapped dconf paths.
  mkCustomKeybindingPath = index: "/${customKeybindingSchema}/custom${toString index}/";
  # Used as a dconf.settings attr key, where Home Manager expects the same path without edge slashes.
  mkCustomKeybindingKey = index: "${customKeybindingSchema}/custom${toString index}";
  customKeybindings =
    map mkCustomKeybindingPath (lib.range 0 6)
    ++ lib.optionals enableAsusRogKeybindings [
      (mkCustomKeybindingPath 7)
      (mkCustomKeybindingPath 8)
    ];
in
{
  config = lib.mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/shell/keybindings" = {
        focus-active-notification = emptyStringArray;
        screenshot = [ "<Shift>F6" ];
        screenshot-window = [ "<Control>F6" ];
        show-screen-recording-ui = [ "<Shift><Super>r" ];
        show-screenshot-ui = [ "F6" ];
        toggle-message-tray = [ "<Super>v" ];
        toggle-quick-settings = [ "<Super>q" ];
      };

      "org/gnome/desktop/wm/keybindings" = {
        maximize = [ "<Super>Up" ];
        maximize-horizontally = emptyStringArray;
        maximize-vertically = [ "<Alt>Up" ];
        move-to-monitor-down = [ "<Alt><Super>Down" ];
        move-to-monitor-left = emptyStringArray;
        move-to-monitor-right = emptyStringArray;
        move-to-workspace-last = [ "<Shift><Alt>Right" ];
        move-to-workspace-left = [ "<Shift><Super>Left" ];
        move-to-workspace-right = [ "<Shift><Super>Right" ];
        toggle-fullscreen = [ "<Super>f" ];
        toggle-maximized = emptyStringArray;
        unmaximize = [
          "<Super>Down"
          "<Alt>F5"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        control-center = [ "<Super>u" ];
        custom-keybindings = customKeybindings;
        email = [ "<Super>m" ];
        home = [ "<Super>n" ];
        next = [ "<Alt>bracketright" ];
        pause = emptyStringArray;
        play = [ "F4" ];
        previous = [ "<Alt>bracketleft" ];
        www = [ "<Super>w" ];
      };

      "${mkCustomKeybindingKey 0}" = {
        binding = "<Alt>o";
        command = "obsidian";
        name = "Obsidian";
      };

      "${mkCustomKeybindingKey 1}" = {
        binding = "<Super>t";
        command = "kitty";
        name = "Terminal";
      };

      "${mkCustomKeybindingKey 2}" = {
        binding = "<Control><Alt>t";
        command = "ticktick";
        name = "TickTick";
      };

      "${mkCustomKeybindingKey 3}" = {
        binding = "<Super>s";
        command = "slack";
        name = "Slack";
      };

      "${mkCustomKeybindingKey 4}" = {
        binding = "<Alt>s";
        command = "spotify";
        name = "Spotify";
      };

      "${mkCustomKeybindingKey 5}" = {
        binding = "<Super>d";
        # nixpkgs' discord ships the binary as "Discord" (capitalised).
        command = "Discord";
        name = "Discord";
      };

      "${mkCustomKeybindingKey 6}" = {
        binding = "<Shift><Super>m";
        command = "missioncenter";
        name = "Mission Center";
      };

      "${mkCustomKeybindingKey 7}" = lib.mkIf enableAsusRogKeybindings {
        binding = "Launch1";
        command = "rog-control-center";
        name = "Rog Control Center";
      };

      "${mkCustomKeybindingKey 8}" = lib.mkIf enableAsusRogKeybindings {
        binding = "F5";
        command = "asusctl profile -n";
        name = "Switch Power profile";
      };
    };
  };
}
