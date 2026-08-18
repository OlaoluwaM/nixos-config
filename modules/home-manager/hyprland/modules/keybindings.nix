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
# Every chord is declared once in `bindDefs` below with a human description
# and a group, and two artifacts derive from that single list:
#   1. the Hyprland lua binds (the description rides along as a bind option,
#      so `hyprctl binds` is self-documenting), and
#   2. ~/.local/share/silere/keybinds.json, the data behind the shell's
#      searchable keybindings viewer (silere.nix points its keybindsFile
#      key here; Super+/ opens the viewer).
# Entries with `viewer = false` bind without cluttering the viewer (the 20
# generated workspace chords collapse into two synthetic rows instead), and
# `viewerExtras` documents chords this module does not own -- the hyprshell
# switcher registers its own binds with the daemon, and gestures are not
# binds at all -- so the viewer still lists them.
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
  qsCommand = lib.getExe' pkgs.quickshell "qs";
  # `qs ipc` locates the running instance by config path, and this shell runs
  # from a Nix store path (silere.nix's ExecStart -p flag), not the default
  # config dir -- a bare `qs ipc call` finds nothing. Every IPC call must
  # carry the same -p the service uses.
  silereIpc = "${qsCommand} -p ${commands.silereShellPackage}/share/silere-shell/shell.qml ipc call";

  execDispatcher = command: "hl.dsp.exec_cmd(${luaString command})";

  # One definition per chord. `flags` holds Hyprland bind options (release,
  # locked, mouse, ...); the description is merged in when the lua bind is
  # rendered, so flags never need to carry it themselves.
  mkDef =
    {
      keys,
      dsp,
      desc,
      group,
      flags ? { },
      viewer ? true,
    }:
    {
      inherit
        keys
        dsp
        desc
        group
        flags
        viewer
        ;
    };

  toLuaBind = d: {
    _args = [
      d.keys
      (lua d.dsp)
      ({ description = d.desc; } // d.flags)
    ];
  };

  # Match Hyprland's standard workspace bindings:
  # Super+1..9 selects workspaces 1..9, Super+0 selects workspace 10.
  # Adding Shift moves the focused window to that workspace. viewer = false:
  # twenty near-identical rows would drown the viewer, so `viewerExtras`
  # carries two collapsed rows for them instead.
  workspaceDefs = lib.concatMap (
    workspace:
    let
      key = if workspace == 10 then "0" else toString workspace;
    in
    [
      (mkDef {
        keys = "${mod} + ${key}";
        dsp = "hl.dsp.focus({ workspace = ${toString workspace} })";
        desc = "Switch to workspace ${toString workspace}";
        group = "Workspaces";
        viewer = false;
      })
      (mkDef {
        keys = "${mod} + SHIFT + ${key}";
        dsp = "hl.dsp.window.move({ workspace = ${toString workspace} })";
        desc = "Move window to workspace ${toString workspace}";
        group = "Workspaces";
        viewer = false;
      })
    ]
  ) (lib.range 1 10);

  bindDefs =
    [
      # -- Applications ------------------------------------------------------
      (mkDef {
        keys = "${mod} + T";
        dsp = execDispatcher terminal;
        desc = "Open a terminal";
        group = "Applications";
      })
      (mkDef {
        keys = "${mod} + W";
        dsp = execDispatcher (lib.getExe pkgs.firefox);
        desc = "Open Firefox";
        group = "Applications";
      })
      (mkDef {
        keys = "ALT + O";
        dsp = execDispatcher (lib.getExe unstable.obsidian);
        desc = "Open Obsidian";
        group = "Applications";
      })
      (mkDef {
        keys = "CTRL + ALT + T";
        dsp = execDispatcher (lib.getExe' pkgs.ticktick "ticktick");
        desc = "Open TickTick";
        group = "Applications";
      })
      # Launch through the desktop entry so the themed override from
      # home/olaolu/default.nix (dark-mode env) applies, matching GNOME.
      (mkDef {
        keys = "${mod} + S";
        dsp = execDispatcher "gtk-launch slack";
        desc = "Open Slack";
        group = "Applications";
      })
      (mkDef {
        keys = "ALT + S";
        dsp = execDispatcher (lib.getExe pkgs.spotify);
        desc = "Open Spotify";
        group = "Applications";
      })
      (mkDef {
        keys = "${mod} + D";
        dsp = execDispatcher (lib.getExe' unstable.discord "Discord");
        desc = "Open Discord";
        group = "Applications";
      })
      (mkDef {
        keys = "${mod} + M";
        dsp = execDispatcher (lib.getExe unstable.protonmail-desktop);
        desc = "Open Proton Mail";
        group = "Applications";
      })
      (mkDef {
        keys = "${mod} + SHIFT + M";
        dsp = execDispatcher "${pkgs.mission-center}/bin/missioncenter";
        desc = "Open Mission Center";
        group = "Applications";
      })
      (mkDef {
        keys = "${mod} + N";
        dsp = execDispatcher "${pkgs.nautilus}/bin/nautilus";
        desc = "Open Files";
        group = "Applications";
      })

      # -- Launcher ----------------------------------------------------------
      (mkDef {
        keys = "${mod} + Space";
        dsp = execDispatcher "${vicinaeCommand} open";
        desc = "Open the launcher";
        group = "Launcher";
      })
      (mkDef {
        keys = "ALT + V";
        dsp = execDispatcher "${vicinaeCommand} 'vicinae://launch/clipboard/history?toggle=true'";
        desc = "Open clipboard history";
        group = "Launcher";
      })
      # "random-wallpaper" is a Vicinae script command (wallpaper.nix,
      # installed under ~/.local/share/vicinae/scripts) that picks a random
      # image from $WALLPAPERS_DIR and calls wallpaper-set. Its installed
      # filename is also its deeplink id -- renaming that script without
      # updating this bind would silently break it. Picking a *specific*
      # wallpaper stays inside Vicinae's own search ("Set Wallpaper") or the
      # CLI (wallpaper-set <path>): Vicinae's script-command argument types
      # have no live-directory picker to bind a chord to.
      (mkDef {
        keys = "${mod} + SHIFT + W";
        dsp = execDispatcher "${vicinaeCommand} 'vicinae://launch/scripts/random-wallpaper'";
        desc = "Set a random wallpaper";
        group = "Launcher";
      })

      # -- Screen capture ----------------------------------------------------
      (mkDef {
        keys = "F6";
        dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot area";
        desc = "Screenshot an area";
        group = "Screen capture";
      })
      (mkDef {
        keys = "SHIFT + F6";
        dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot full";
        desc = "Screenshot the screen";
        group = "Screen capture";
      })
      (mkDef {
        keys = "CTRL + F6";
        dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot window";
        desc = "Screenshot the focused window";
        group = "Screen capture";
      })
      (mkDef {
        keys = "${mod} + SHIFT + R";
        dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record area";
        desc = "Record an area of the screen";
        group = "Screen capture";
      })
      (mkDef {
        keys = "${mod} + CTRL + R";
        dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record full";
        desc = "Record the screen";
        group = "Screen capture";
      })
      (mkDef {
        keys = "${mod} + ALT + R";
        dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record stop";
        desc = "Stop the recording";
        group = "Screen capture";
      })

      # -- Session -----------------------------------------------------------
      (mkDef {
        keys = "${mod} + L";
        dsp = execDispatcher "${pkgs.systemd}/bin/loginctl lock-session";
        desc = "Lock the screen";
        group = "Session";
      })
      # Same hypr-shell-caffeine.service the shell's menu row and mug pill
      # control -- one unit, so chord and UI can never disagree. The script
      # goes through the shell's IPC first, so the chord starts a run with
      # the last chosen preset and the pill lights instantly.
      (mkDef {
        keys = "${mod} + C";
        dsp = execDispatcher "${commands.caffeineScript}/bin/hypr-shell-caffeine toggle";
        desc = "Toggle caffeine";
        group = "Session";
      })
      (mkDef {
        keys = "${mod} + slash";
        dsp = execDispatcher "${silereIpc} keybinds toggle";
        desc = "Show keyboard shortcuts";
        group = "Session";
      })
      # GNOME parity: <Super>v is toggle-message-tray there. Unlike Super+Q
      # this opens/raises only -- the menu IPC has no per-tab toggle -- so
      # Escape closes. Plain V is free: float is Super+SHIFT+V, clipboard
      # history is ALT+V.
      (mkDef {
        keys = "${mod} + V";
        dsp = execDispatcher "${silereIpc} menu show notifications";
        desc = "Show notifications";
        group = "Session";
      })
      # GNOME parity: <Super>q is toggle-quick-settings there (see the GNOME
      # profile's keybindings.nix). `menu toggle` is the exact counterpart:
      # it opens the menu on its Home tab and closes it when already open.
      # (Landing on the Settings tab was tried first and rolled back -- the
      # user wants Home.)
      (mkDef {
        keys = "${mod} + Q";
        dsp = execDispatcher "${silereIpc} menu toggle";
        desc = "Toggle the shell menu";
        group = "Session";
      })

      # -- Windows -----------------------------------------------------------
      (mkDef {
        keys = "${mod} + SHIFT + Q";
        dsp = "hl.dsp.window.close()";
        desc = "Close the window";
        group = "Windows";
      })
      (mkDef {
        keys = "ALT + F4";
        dsp = "hl.dsp.window.close()";
        desc = "Close the window";
        group = "Windows";
      })
      (mkDef {
        keys = "${mod} + F";
        dsp = "hl.dsp.window.fullscreen()";
        desc = "Toggle fullscreen";
        group = "Windows";
      })
      (mkDef {
        keys = "${mod} + Up";
        dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\" })";
        desc = "Maximize the window";
        group = "Windows";
      })
      (mkDef {
        keys = "${mod} + Down";
        dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })";
        desc = "Unmaximize the window";
        group = "Windows";
      })
      (mkDef {
        keys = "ALT + F5";
        dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })";
        desc = "Unmaximize the window";
        group = "Windows";
        viewer = false;
      })
      (mkDef {
        keys = "${mod} + SHIFT + V";
        dsp = "hl.dsp.window.float()";
        desc = "Toggle floating";
        group = "Windows";
      })
    ]
    ++ workspaceDefs
    ++ [
      # Scroll through existing workspaces with Super + scroll.
      (mkDef {
        keys = "${mod} + mouse_down";
        dsp = "hl.dsp.focus({ workspace = \"e+1\" })";
        desc = "Next workspace (scroll)";
        group = "Workspaces";
      })
      (mkDef {
        keys = "${mod} + mouse_up";
        dsp = "hl.dsp.focus({ workspace = \"e-1\" })";
        desc = "Previous workspace (scroll)";
        group = "Workspaces";
      })

      # Release binds are useful for "press Super by itself" behavior because
      # they avoid firing before Hyprland knows whether Super is part of a combo.
      (mkDef {
        keys = "${mod} + SUPER_L";
        dsp = execDispatcher "${vicinaeCommand} open";
        desc = "Open the launcher (tap Super)";
        group = "Launcher";
        flags.release = true;
        viewer = false;
      })
      (mkDef {
        keys = "${mod} + SUPER_R";
        dsp = execDispatcher "${vicinaeCommand} open";
        desc = "Open the launcher (tap Super)";
        group = "Launcher";
        flags.release = true;
        viewer = false;
      })

      # Mouse binds keep running while the mouse button is held. Used here so
      # Super+left-drag moves a window and Super+right-drag resizes one.
      (mkDef {
        keys = "${mod} + mouse:272";
        dsp = "hl.dsp.window.drag()";
        desc = "Move window (drag)";
        group = "Windows";
        flags.mouse = true;
      })
      (mkDef {
        keys = "${mod} + mouse:273";
        dsp = "hl.dsp.window.resize()";
        desc = "Resize window (drag)";
        group = "Windows";
        flags.mouse = true;
      })

      # Stock Hyprland has no shell OSD, so these direct device commands are
      # the only thing keeping the hardware keys usable, including while
      # locked. viewer = false: hardware keys are self-describing.
      (mkDef {
        keys = "XF86AudioRaiseVolume";
        dsp = execDispatcher "${wpctlCommand} set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        desc = "Raise the volume";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
      (mkDef {
        keys = "XF86AudioLowerVolume";
        dsp = execDispatcher "${wpctlCommand} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        desc = "Lower the volume";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
      (mkDef {
        keys = "XF86AudioMute";
        dsp = execDispatcher "${wpctlCommand} set-mute @DEFAULT_AUDIO_SINK@ toggle";
        desc = "Mute the audio";
        group = "Hardware";
        flags.locked = true;
        viewer = false;
      })
      (mkDef {
        keys = "XF86MonBrightnessUp";
        dsp = execDispatcher "${brightnessCommand} set 5%+";
        desc = "Raise the brightness";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
      (mkDef {
        keys = "XF86MonBrightnessDown";
        dsp = execDispatcher "${brightnessCommand} set 5%-";
        desc = "Lower the brightness";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
      (mkDef {
        keys = "XF86KbdBrightnessUp";
        dsp = execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%+";
        desc = "Raise the keyboard backlight";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
      (mkDef {
        keys = "XF86KbdBrightnessDown";
        dsp = execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%-";
        desc = "Lower the keyboard backlight";
        group = "Hardware";
        flags = {
          locked = true;
          repeating = true;
        };
        viewer = false;
      })
    ]
    # Super+Alt+W (wifi), Super+B (bluetooth), and
    # Super+Escape/XF86PowerOff (session) are intentionally unbound: their
    # old shell targets are gone. They come back once the new silere shell
    # surfaces them. Super+Q (settings) and Super+Shift+W (wallpapers) are
    # bound above.
    ++ lib.optionals enableAsusRogKeybindings [
      (mkDef {
        keys = "XF86Launch1";
        dsp = execDispatcher (lib.getExe' pkgs.asusctl "rog-control-center");
        desc = "Open ROG Control Center";
        group = "Hardware";
      })
      (mkDef {
        keys = "F5";
        dsp = execDispatcher "${lib.getExe' pkgs.asusctl "asusctl"} profile -n";
        desc = "Cycle the power profile";
        group = "Hardware";
      })
    ];

  # Chords the viewer should list that this module does not bind: hyprshell's
  # daemon registers the switcher binds itself (hyprshell.nix), the workspace
  # number chords collapse from twenty generated binds into two rows, and the
  # swipe is a gesture, not a bind.
  viewerExtras = [
    {
      keys = "ALT + Tab";
      desc = "Switch windows";
      group = "Workspaces";
    }
    {
      keys = "${mod} + 1–9, 0";
      desc = "Switch to workspace 1–10";
      group = "Workspaces";
    }
    {
      keys = "${mod} + SHIFT + 1–9, 0";
      desc = "Move window to workspace 1–10";
      group = "Workspaces";
    }
    {
      keys = "3-finger swipe";
      desc = "Switch workspaces (past the end creates one)";
      group = "Workspaces";
    }
  ];

  viewerEntries =
    map (d: {
      inherit (d) keys desc group;
    }) (lib.filter (d: d.viewer) bindDefs)
    ++ viewerExtras;
in
{
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      bind = map toLuaBind bindDefs;
    };

    # The viewer data the shell's Keybinds service reads (silere.nix points
    # local.hyprland.silere.keybindsFile here). Derived from bindDefs above,
    # so a chord and its documentation can never drift apart.
    xdg.dataFile."silere/keybinds.json".text = builtins.toJSON viewerEntries;

    # Third entry point into the viewer, alongside Super+slash and the qs CLI:
    # a desktop entry makes it launchable from Vicinae's app search ("Keyboard
    # Shortcuts"). Exec is the same IPC call the chord runs -- it toggles the
    # popup in the running shell rather than spawning anything, so the entry
    # is safe to "launch" repeatedly. Lives here, not silere.nix, because the
    # viewer's other artifacts (chord, JSON) are declared in this module.
    xdg.desktopEntries.silere-keybinds = {
      name = "Keyboard Shortcuts";
      comment = "Search the Hyprland and shell keybindings";
      exec = "${silereIpc} keybinds toggle";
      icon = "preferences-desktop-keyboard-shortcuts";
      terminal = false;
      categories = [
        "Utility"
        "Settings"
      ];
    };
  };
}
