{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This module owns every Hyprland key chord: application launches,
# screenshot/screenrecord binds, window management, workspace switching,
# mouse drag/resize, and the hardware media/brightness keys. Window rules,
# compositor config (input/general/decoration/animations/monitor), and
# services stay in default.nix.
#
# AGENTS.md's rule to keep equivalent GNOME and Hyprland keybindings on the
# same chord applies here: before changing a binding, check the GNOME
# profile and preserve parity unless a desktop-specific constraint requires
# an intentional difference.
let
  cfg = config.local.hyprland;
  commands = cfg.commands;
  enableAsusRogKeybindings = config.local.capabilities.input.asusRogKeys;
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  mod = "SUPER";
  terminal = "kitty";

  vicinaeCommand = lib.getExe' config.programs.vicinae.package "vicinae";
  brightnessCommand = lib.getExe pkgs.brightnessctl;
  wpctlCommand = lib.getExe' pkgs.wireplumber "wpctl";

  execDispatcher = command: "hl.dsp.exec_cmd(${luaString command})";
  mkBind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
    ];
  };
  mkBindWithFlags = keys: dispatcher: flags: {
    _args = [
      keys
      (lua dispatcher)
      flags
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Plain binds run once when the key is pressed.
      bind = [
        (mkBind "${mod} + T" (execDispatcher terminal))
        (mkBind "${mod} + W" (execDispatcher (lib.getExe pkgs.firefox)))
        (mkBind "${mod} + O" (execDispatcher (lib.getExe unstable.obsidian)))
        (mkBind "CTRL + ALT + T" (execDispatcher (lib.getExe' pkgs.ticktick "ticktick")))
        (mkBind "${mod} + S" (execDispatcher (lib.getExe pkgs.slack)))
        (mkBind "ALT + S" (execDispatcher (lib.getExe pkgs.spotify)))
        (mkBind "${mod} + D" (execDispatcher (lib.getExe' unstable.discord "Discord")))

        (mkBind "${mod} + Space" (execDispatcher "${vicinaeCommand} open"))
        (mkBind "ALT + V" (
          execDispatcher "${vicinaeCommand} 'vicinae://launch/clipboard/history?toggle=true'"
        ))

        (mkBind "F6" (execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot area"))
        (mkBind "SHIFT + F6" (execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot full"))
        (mkBind "CTRL + F6" (
          execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot window"
        ))

        (mkBind "${mod} + SHIFT + R" (
          execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record area"
        ))
        (mkBind "${mod} + CTRL + R" (
          execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record full"
        ))
        (mkBind "${mod} + ALT + R" (
          execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record stop"
        ))

        (mkBind "${mod} + N" (execDispatcher "${pkgs.nautilus}/bin/nautilus"))
        (mkBind "${mod} + L" (execDispatcher "${pkgs.systemd}/bin/loginctl lock-session"))

        (mkBind "${mod} + M" (execDispatcher (lib.getExe unstable.protonmail-desktop)))
        (mkBind "${mod} + SHIFT + M" (execDispatcher "${pkgs.mission-center}/bin/missioncenter"))

        (mkBind "${mod} + SHIFT + Q" "hl.dsp.window.close()")
        (mkBind "ALT + F4" "hl.dsp.window.close()")

        (mkBind "${mod} + F" "hl.dsp.window.fullscreen()")
        (mkBind "${mod} + Up" "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\" })")
        (mkBind "${mod} + Down" "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })")
        (mkBind "ALT + F5" "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })")
        (mkBind "${mod} + SHIFT + V" "hl.dsp.window.float()")

        (mkBind "${mod} + 1" "hl.dsp.focus({ workspace = 1 })")
        (mkBind "${mod} + 2" "hl.dsp.focus({ workspace = 2 })")
        (mkBind "${mod} + 3" "hl.dsp.focus({ workspace = 3 })")
        (mkBind "${mod} + 4" "hl.dsp.focus({ workspace = 4 })")
        (mkBind "${mod} + 5" "hl.dsp.focus({ workspace = 5 })")

        (mkBind "${mod} + SHIFT + 1" "hl.dsp.window.move({ workspace = 1 })")
        (mkBind "${mod} + SHIFT + 2" "hl.dsp.window.move({ workspace = 2 })")
        (mkBind "${mod} + SHIFT + 3" "hl.dsp.window.move({ workspace = 3 })")
        (mkBind "${mod} + SHIFT + 4" "hl.dsp.window.move({ workspace = 4 })")
        (mkBind "${mod} + SHIFT + 5" "hl.dsp.window.move({ workspace = 5 })")

        # Release binds are useful for "press Super by itself" behavior because
        # they avoid firing before Hyprland knows whether Super is part of a combo.
        (mkBindWithFlags "${mod} + SUPER_L" (execDispatcher "${vicinaeCommand} open") { release = true; })
        (mkBindWithFlags "${mod} + SUPER_R" (execDispatcher "${vicinaeCommand} open") { release = true; })

        # Mouse binds keep running while the mouse button is held. Used here so
        # Super+left-drag moves a window and Super+right-drag resizes one.
        (mkBindWithFlags "${mod} + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (mkBindWithFlags "${mod} + mouse:273" "hl.dsp.window.resize()" { mouse = true; })

        # Stock Hyprland has no shell OSD, so these direct device commands are
        # the only thing keeping the hardware keys usable, including while
        # locked.
        (mkBindWithFlags "XF86AudioRaiseVolume"
          (execDispatcher "${wpctlCommand} set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
          {
            locked = true;
            repeating = true;
          }
        )
        (mkBindWithFlags "XF86AudioLowerVolume"
          (execDispatcher "${wpctlCommand} set-volume @DEFAULT_AUDIO_SINK@ 5%-")
          {
            locked = true;
            repeating = true;
          }
        )
        (mkBindWithFlags "XF86AudioMute"
          (execDispatcher "${wpctlCommand} set-mute @DEFAULT_AUDIO_SINK@ toggle")
          { locked = true; }
        )
        (mkBindWithFlags "XF86MonBrightnessUp" (execDispatcher "${brightnessCommand} set 5%+") {
          locked = true;
          repeating = true;
        })
        (mkBindWithFlags "XF86MonBrightnessDown" (execDispatcher "${brightnessCommand} set 5%-") {
          locked = true;
          repeating = true;
        })
        (mkBindWithFlags "XF86KbdBrightnessUp"
          (execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%+")
          {
            locked = true;
            repeating = true;
          }
        )
        (mkBindWithFlags "XF86KbdBrightnessDown"
          (execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%-")
          {
            locked = true;
            repeating = true;
          }
        )
      ]
      # Super+Shift+W (wallpapers), Super+Q (settings), Super+Alt+W (wifi),
      # Super+B (bluetooth), Super+Escape/XF86PowerOff (session) are
      # intentionally unbound: their old shell targets are gone. They come
      # back once the new silere shell lands.
      ++ lib.optionals enableAsusRogKeybindings [
        (mkBind "XF86Launch1" (execDispatcher (lib.getExe' unstable.asusctl "rog-control-center")))
        (mkBind "F5" (execDispatcher "${lib.getExe' unstable.asusctl "asusctl"} profile -n"))
      ];
    };
  };
}
