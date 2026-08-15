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

  # Match Hyprland's standard workspace bindings:
  # Super+1..9 selects workspaces 1..9, Super+0 selects workspace 10.
  # Adding Shift moves the focused window to that workspace.
  workspaceBinds = lib.concatMap (
    workspace:
    let
      key = if workspace == 10 then "0" else toString workspace;
    in
    [
      (mkBind "${mod} + ${key}" "hl.dsp.focus({ workspace = ${toString workspace} })")
      (mkBind "${mod} + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${toString workspace} })")
    ]
  ) (lib.range 1 10);
in
{
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Plain binds run once when the key is pressed.
      bind = [
        (mkBind "${mod} + T" (execDispatcher terminal))
        (mkBind "${mod} + W" (execDispatcher (lib.getExe pkgs.firefox)))
        (mkBind "ALT + O" (execDispatcher (lib.getExe unstable.obsidian)))
        (mkBind "CTRL + ALT + T" (execDispatcher (lib.getExe' pkgs.ticktick "ticktick")))
        # Launch through the desktop entry so the themed override from
        # home/olaolu/default.nix (dark-mode env) applies, matching GNOME.
        (mkBind "${mod} + S" (execDispatcher "gtk-launch slack"))
        (mkBind "ALT + S" (execDispatcher (lib.getExe pkgs.spotify)))
        (mkBind "${mod} + D" (execDispatcher (lib.getExe' unstable.discord "Discord")))

        (mkBind "${mod} + Space" (execDispatcher "${vicinaeCommand} open"))
        (mkBind "ALT + V" (
          execDispatcher "${vicinaeCommand} 'vicinae://launch/clipboard/history?toggle=true'"
        ))

        # "random-wallpaper" is a Vicinae script command (wallpaper.nix,
        # installed under ~/.local/share/vicinae/scripts) that picks a random
        # image from $WALLPAPERS_DIR and calls wallpaper-set. Its installed
        # filename is also its deeplink id -- renaming that script without
        # updating this bind would silently break it. Picking a *specific*
        # wallpaper stays inside Vicinae's own search ("Set Wallpaper") or the
        # CLI (wallpaper-set <path>): Vicinae's script-command argument types
        # have no live-directory picker to bind a chord to.
        (mkBind "${mod} + SHIFT + W" (
          execDispatcher "${vicinaeCommand} 'vicinae://launch/scripts/random-wallpaper'"
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
      ]
      ++ workspaceBinds
      ++ [
        # Scroll through existing workspaces with Super + scroll.
        (mkBind "${mod} + mouse_down" "hl.dsp.focus({ workspace = \"e+1\" })")
        (mkBind "${mod} + mouse_up" "hl.dsp.focus({ workspace = \"e-1\" })")

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
      # Super+Q (settings), Super+Alt+W (wifi), Super+B (bluetooth),
      # Super+Escape/XF86PowerOff (session) are intentionally unbound: their
      # old shell targets are gone. They come back once the new silere shell
      # lands. Super+Shift+W (wallpapers) is bound above -- the wallpaper
      # pipeline doesn't depend on the rest of the shell surfacing them.
      ++ lib.optionals enableAsusRogKeybindings [
        (mkBind "XF86Launch1" (execDispatcher (lib.getExe' pkgs.asusctl "rog-control-center")))
        (mkBind "F5" (execDispatcher "${lib.getExe' pkgs.asusctl "asusctl"} profile -n"))
      ];
    };
  };
}
