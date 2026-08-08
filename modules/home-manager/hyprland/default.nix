{
  config,
  hostConfig,
  lib,
  pkgs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This is the entry point for the Home Manager side of the Hyprland profile.
# "Entry point" means other config files import this module, and this module
# imports the smaller Hyprland-related files below.
#
# The split is:
# - default.nix: compositor config, session target, keybinds, wallpaper/session
#   plumbing, shared packages, portals
# - quickshell.nix: top bar, generated QML, Quickshell service, QML helper
#   scripts
# - hyprlock.nix: lock-screen look and behavior
# - hypridle.nix: idle locking behavior
#
# Home Manager source/options:
# https://nix-community.github.io/home-manager/options.xhtml
let
  cfg = config.local.hyprland;
  commands = cfg.commands;
  theme = config.local.theme.colors;
  stripHash = s: lib.removePrefix "#" s;
  hyprlandSessionTarget = "hyprland-session.target";
  enableAsusRogKeybindings = hostConfig.enableAsusRogKeybindings or false;
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  mod = "SUPER";
  terminal = "kitty";

  vicinaeCommand = lib.getExe' config.programs.vicinae.package "vicinae";

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

  airctl = pkgs.callPackage ../../../pkgs/airctl { };

  # Wallpaper folder used by Waypaper. If WALLPAPERS_DIR is set in the session
  # environment, use that. Otherwise fall back to ~/Pictures/wallpapers.
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/wallpapers";

  # Waypaper manages the desktop wallpaper. Hyprlock still needs one stable file
  # path for its background, so Waypaper runs this tiny hook after a wallpaper is
  # selected. The hook only updates the lock-screen symlink; it does not choose
  # or apply wallpapers.
  wallpaperLockHook = pkgs.writeShellApplication {
    name = "hypr-shell-lock-wallpaper";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      wallpaper="''${1:-}"

      if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
        exit 0
      fi

      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/hypr-shell"
      mkdir -p "$cache_dir"
      ln -sfn "$wallpaper" "$cache_dir/lock-wallpaper"
    '';
  };

  # Screenshot script wraps grim/slurp/satty into one command with modes for
  # area, full-screen, and active-window screenshots.
  screenshotScript = pkgs.writeShellApplication {
    name = "hypr-shell-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      hyprland
      jq
      libnotify
      satty
      slurp
      wl-clipboard
      xdg-utils
    ];
    text = builtins.readFile ./scripts/hypr-shell-screenshot.sh;
  };

  screenrecordScript = pkgs.writeShellApplication {
    name = "hypr-shell-record";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      procps
      slurp
      wf-recorder
      xdg-utils
    ];
    text = builtins.readFile ./scripts/hypr-shell-screenrecord.sh;
  };
in
{
  # Import the focused modules that make up the riced Hyprland session.
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ../vicinae.nix
    ./quickshell.nix
  ];

  options.local.hyprland = {
    # Creates the option local.hyprland.enable. Other files can set this to true
    # to enable the whole Home Manager Hyprland profile.
    enable = lib.mkEnableOption "Hyprland configuration";

    # Shared internal values, not normal user-facing settings. Think like shared
    # internal state without the usual enforcement by native language facilities, like in Python.
    # These internal "options" are meant solely to expose stuff to other modules within this Hyprland
    # module config and should not be "set" like regular module options.
    #
    # A `let` value in this file would only be visible in this file. We needed a way to
    # share some package paths with other Hyprland modules. This was the solution we chose.
    # Putting them under config.local.hyprland.commands gives every Hyprland module one shared
    # place to read the same helper commands from, but discourage writing to.
    #
    # These live under local.hyprland, not local.hyprland.quickshell, because
    # they belong to the whole Hyprland session: default.nix uses them for
    # keybinds/packages, while quickshell.nix reuses the same commands when it
    # generates QML. `internal = true` marks these as shared values for the
    # Hyprland module files in this directory, not settings users are expected
    # to configure/set directly.
    commands = {
      airctl = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Packaged airctl helper used by Hyprland keybinds.";
      };

      screenshotScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Packaged screenshot helper used by Hyprland keybinds.";
      };

      screenrecordScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Packaged screen recording helper used by Hyprland keybinds.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    local.hyprland.commands = {
      inherit
        airctl
        screenshotScript
        screenrecordScript
        ;
    };

    local.vicinae.enable = true;
    local.vicinae.systemd.target = hyprlandSessionTarget;

    # Tells Home Manager which user systemd target represents "the Hyprland
    # desktop session is running." Services such as Quickshell, hypridle,
    # hyprsunset, Vicinae, and wallpaper restore attach themselves to this same
    # target, so they start when Hyprland starts and stop when the Hyprland
    # session stops. Without one shared target, each service would need its own
    # separate start/stop rules and they could drift out of sync.
    wayland.systemd.target = hyprlandSessionTarget;

    wayland.windowManager.hyprland = {
      enable = true;

      # The NixOS module already installs Hyprland and its portal package. Home
      # Manager's wayland.windowManager.hyprland.package docs say to set this
      # to null when the NixOS module installs Hyprland:
      # https://nix-community.github.io/home-manager/options.xhtml#opt-wayland.windowManager.hyprland.package
      #
      # Home Manager owns the user config and hyprland-session.target here. The
      # Home Manager module also contributes the Hyprland portal to xdg.portal;
      # the GTK portal fallback is configured below.
      package = null;

      # Hyprland 0.55+ and Home Manager 26.05 support Lua config generation.
      # Keep this explicit so the profile writes ~/.config/hypr/hyprland.lua
      # regardless of future Home Manager default changes.
      configType = "lua";

      # When Hyprland starts, Home Manager can copy important session variables
      # into the environment inherited by services run through `systemctl --user`
      # before starting hyprland-session.target. Services started this way, such
      # as Quickshell, hypridle, hyprsunset, Vicinae, and wallpaper restore, need
      # these values to know which Wayland/Hyprland session they belong to.
      # Without them, those services can start but fail to talk to the compositor,
      # portals, or the right display.
      systemd = {
        enable = true;
        variables = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_DESKTOP"
          "XDG_SESSION_TYPE"
          # Repo-specific: used by Waypaper/wallpaper restore helpers.
          "WALLPAPERS_DIR"
        ];
      };

      settings = {
        # Monitor rule. Blank monitor name means "apply to all monitors".
        # preferred = use the monitor's preferred resolution/refresh rate.
        # auto = let Hyprland choose the position. 1 = scale factor.
        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        };

        env = [
          {
            _args = [
              "XDG_CURRENT_DESKTOP"
              "Hyprland"
            ];
          }
          {
            _args = [
              "XDG_SESSION_DESKTOP"
              "Hyprland"
            ];
          }
          {
            _args = [
              "NIXOS_OZONE_WL"
              "1"
            ];
          }
        ];

        # Runs when Hyprland is already shutting down so no need for hyprshutdown.
        on = {
          _args = [
            "hyprland.shutdown"
            (lua ''
              function()
                hl.exec_cmd(${luaString "${pkgs.systemd}/bin/systemctl --user stop ${hyprlandSessionTarget}"})
              end
            '')
          ];
        };

        config = {
          input = {
            kb_layout = "us";
            follow_mouse = 1;
            touchpad.natural_scroll = true;
          };

          general = {
            gaps_in = 4;
            gaps_out = 8;
            border_size = 2;
            "col.active_border" = "rgb(${stripHash theme.primary})";
            "col.inactive_border" = "rgb(${stripHash theme.outline})";
            layout = "dwindle";
          };

          decoration = {
            rounding = 14;
            rounding_power = 3.5;
            blur = {
              enabled = true;
              size = 5;
              passes = 2;
            };
            shadow = {
              enabled = true;
              range = 12;
              render_power = 2;
              color = "rgba(${stripHash theme.shadowColor})";
            };
          };

          animations = {
            enabled = true;
          };

          dwindle = {
            preserve_split = true;
          };

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            focus_on_activate = true;
          };
        };

        curve = {
          _args = [
            "easeOut"
            {
              type = "bezier";
              points = [
                [
                  0.22
                  1
                ]
                [
                  0.36
                  1
                ]
              ];
            }
          ];
        };

        animation = [
          {
            leaf = "windows";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
          {
            leaf = "border";
            enabled = true;
            speed = 4;
            bezier = "default";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
        ];

        window_rule = [
          {
            match.class = "^(vicinae)$";
            float = true;
          }
          {
            match.class = "^(vicinae)$";
            center = true;
          }
          {
            match.class = "^(vicinae)$";
            size = "42% 48%";
          }
          {
            match.class = "^(io.github.airctl)$";
            float = true;
          }
          {
            match.class = "^(io.github.kaii_lb.Overskride)$";
            float = true;
          }
          {
            match.class = "^(mission-center)$";
            float = true;
          }
        ];

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

          (mkBind "${mod} + SHIFT + W" (execDispatcher "${unstable.waypaper}/bin/waypaper"))

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

          # See ShellShortcuts.qml: Hyprland owns the key chord, Quickshell owns
          # the named shell actions.
          (mkBind "${mod} + Q" "hl.dsp.global(\"quickshell:quickSettings\")")

          (mkBind "${mod} + N" (execDispatcher "${pkgs.nautilus}/bin/nautilus"))
          (mkBind "${mod} + ALT + W" (execDispatcher "${commands.airctl}/bin/airctl"))
          (mkBind "${mod} + B" (execDispatcher "${unstable.overskride}/bin/overskride"))

          (mkBind "${mod} + M" (execDispatcher (lib.getExe pkgs.protonmail-desktop)))
          (mkBind "${mod} + SHIFT + M" (execDispatcher "${pkgs.mission-center}/bin/missioncenter"))

          (mkBind "${mod} + Escape" (execDispatcher "${unstable.hyprshutdown}/bin/hyprshutdown"))
          (mkBind "XF86PowerOff" (execDispatcher "${unstable.hyprshutdown}/bin/hyprshutdown"))

          (mkBind "${mod} + L" (execDispatcher "${pkgs.systemd}/bin/loginctl lock-session"))

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

          # Locked binds allow media keys even when input is inhibited, such as
          # while the lock screen is active. ShellShortcuts.qml owns hold-repeat
          # behavior so a tap cannot turn into a flood of global shortcut activations.
          (mkBindWithFlags "XF86AudioRaiseVolume" "hl.dsp.global(\"quickshell:audioUp\")" { locked = true; })
          (mkBindWithFlags "XF86AudioLowerVolume" "hl.dsp.global(\"quickshell:audioDown\")" {
            locked = true;
          })
          (mkBindWithFlags "XF86AudioMute" "hl.dsp.global(\"quickshell:audioMute\")" { locked = true; })

          (mkBindWithFlags "XF86MonBrightnessUp" "hl.dsp.global(\"quickshell:brightnessUp\")" {
            locked = true;
          })
          (mkBindWithFlags "XF86MonBrightnessDown" "hl.dsp.global(\"quickshell:brightnessDown\")" {
            locked = true;
          })

          (mkBindWithFlags "XF86KbdBrightnessUp" "hl.dsp.global(\"quickshell:keyboardBrightnessUp\")" {
            locked = true;
          })
          (mkBindWithFlags "XF86KbdBrightnessDown" "hl.dsp.global(\"quickshell:keyboardBrightnessDown\")" {
            locked = true;
          })

          # Mouse binds keep running while the mouse button is held. Used here so
          # Super+left-drag moves a window and Super+right-drag resizes one.
          (mkBindWithFlags "${mod} + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
          (mkBindWithFlags "${mod} + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
        ]
        ++ lib.optionals enableAsusRogKeybindings [
          (mkBind "XF86Launch1" (execDispatcher (lib.getExe' unstable.asusctl "rog-control-center")))
          (mkBind "F5" (execDispatcher "${lib.getExe' unstable.asusctl "asusctl"} profile -n"))
        ];
      };
    };

    # Baseline user packages for the Hyprland profile. These are not all visible
    # apps; some are fonts and Qt support libraries that make the UI render
    # correctly.
    home.packages = with pkgs; [
      # General font/icon support. The Quickshell bar should not depend on Nerd
      # Font glyph icons; it uses SVG icons instead. The symbols font is kept as
      # a broad fallback for terminal/app text that may still contain those
      # characters outside this shell. Noto (incl. color emoji) comes from the
      # fontconfig module, which owns the fallback fonts for every profile.
      font-awesome
      nerd-fonts.symbols-only

      # Qt Wayland/QML support. Quickshell is a Qt/QML program, so these help
      # editor tooling and Qt apps understand the Wayland session.
      libsForQt5.qtwayland
      nautilus
      qt6.qtdeclarative
      qt6.qtimageformats
      qt6.qtsvg
      qt6.qtwayland

      # Hyprland session utilities and apps launched by the keybinds above.
      brightnessctl
      commands.airctl
      commands.screenrecordScript
      commands.screenshotScript
      grim
      jq
      libnotify
      # Image viewer and PDF reader for the session; GNOME ships equivalents as
      # part of the desktop, Hyprland has to bring its own. These two are the
      # defaults declared in xdg.mimeApps below.
      loupe
      mission-center
      papers
      satty
      slurp
      unstable.awww
      unstable.hyprshutdown
      unstable.overskride
      unstable.waypaper
      wayland-pipewire-idle-inhibit
      wf-recorder
    ];

    # Everyday file-type defaults for the Hyprland session, merged into the
    # xdg.mimeApps set that desktop.nix enables. GNOME gets these as stock
    # desktop defaults; outside GNOME they must be declared, or xdg-open falls
    # back to whatever app happens to advertise the type (opening a directory
    # in VS Code, say). Loupe and Papers are installed above; Nautilus is in
    # this module's Qt/Wayland group, VLC and Gapless come from home.packages.
    xdg.mimeApps.defaultApplications =
      lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/svg+xml"
        "image/bmp"
        "image/tiff"
        "image/avif"
      ] (_: "org.gnome.Loupe.desktop")
      // lib.genAttrs [
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/mpeg"
        "video/x-msvideo"
        "video/quicktime"
      ] (_: "vlc.desktop")
      // lib.genAttrs [
        "audio/mpeg"
        "audio/flac"
        "audio/ogg"
        "audio/x-vorbis+ogg"
        "audio/mp4"
        "audio/x-wav"
      ] (_: "com.github.neithern.g4music.desktop")
      // {
        "application/pdf" = "org.gnome.Papers.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };

    home.sessionVariables = {
      # Helps Chromium/Electron apps prefer Wayland behavior under NixOS.
      NIXOS_OZONE_WL = "1";
    };

    # .desktop entry for waypaper so it can show up in app launchers like vicinae
    xdg.desktopEntries.waypaper = {
      name = "Waypaper";
      genericName = "Wallpaper Picker";
      comment = "Pick and apply wallpapers for the Hyprland session";
      exec = "${unstable.waypaper}/bin/waypaper";
      icon = "waypaper";
      terminal = false;
      categories = [
        "Utility"
        "GTK"
        "DesktopSettings"
      ];
    };

    # Waypaper is the wallpaper picker. awww is the background daemon that
    # actually draws the wallpaper on the Wayland outputs.
    xdg.configFile."waypaper/config.ini".text = ''
      [Settings]
      language = en
      folder = ${wallpapersDir}
      backend = awww
      monitors = All
      fill = Fill
      sort = name
      color = ${theme.lockBackground}
      subfolders = False
      all_subfolders = False
      show_hidden = False
      show_gifs_only = False
      show_path_in_tooltip = True
      number_of_columns = 3
      use_xdg_state = True
      zen_mode = False

      # Waypaper replaces $wallpaper with an escaped file path. Leave it
      # unquoted here so paths with spaces still reach the hook correctly.
      post_command = ${wallpaperLockHook}/bin/hypr-shell-lock-wallpaper $wallpaper
    '';

    # udiskie watches removable drives. automount=true means USB drives can show
    # up automatically without manually running mount commands.
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
    };

    services.hypridle.systemdTarget = hyprlandSessionTarget;

    services.hyprpolkitagent.enable = true;

    # hyprsunset shifts the display color temperature later in the day. Lower
    # temperature values look warmer/oranger. This is separate from the QML UI.
    services.hyprsunset = {
      enable = true;
      systemdTarget = hyprlandSessionTarget;
      settings = {
        profile = [
          {
            time = "7:00";
            identity = true;
          }
          {
            time = "19:00";
            temperature = 5000;
          }
          {
            time = "22:00";
            temperature = 4200;
          }
        ];
      };
    };

    # Extra Hyprland-session user services that do not have dedicated Home
    # Manager modules in this config. Quickshell, Vicinae, hypridle, and
    # hyprsunset are configured elsewhere; these are the remaining session
    # helpers that need to start and stop with hyprland-session.target.
    systemd.user.services = {
      # awww is the wallpaper backend daemon. Waypaper chooses the wallpaper,
      # but awww is the process that actually draws it on the Wayland outputs.
      hypr-shell-awww = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = [ hyprlandSessionTarget ];
        };

        Install.WantedBy = [ hyprlandSessionTarget ];

        Service = {
          ExecStart = "${unstable.awww}/bin/awww-daemon";
          Restart = "on-failure";
        };
      };

      # Restore the last Waypaper-selected wallpaper after awww is running.
      # This is a oneshot because it applies the saved wallpaper and then exits.
      hypr-shell-waypaper-restore = {
        Unit = {
          Description = "Restore Waypaper wallpaper";
          After = [ "hypr-shell-awww.service" ];
          PartOf = [ hyprlandSessionTarget ];
        };

        Install.WantedBy = [ hyprlandSessionTarget ];

        Service = {
          Type = "oneshot";
          ExecStart = "${unstable.waypaper}/bin/waypaper --restore";
          Environment = [ "WALLPAPERS_DIR=${wallpapersDir}" ];
        };
      };

      # Block idle while PipeWire reports active media playback, so videos,
      # calls, and similar media do not let hypridle lock the session.
      hypr-shell-media-idle-inhibit = {
        Unit = {
          Description = "Inhibit idle while PipeWire media is playing";
          PartOf = [ hyprlandSessionTarget ];
        };

        Install.WantedBy = [ hyprlandSessionTarget ];

        Service = {
          ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit";
          Restart = "on-failure";
        };
      };
    };

    # xdg-desktop-portal 1.17+ requires an explicit backend selection when
    # portals are enabled. The Home Manager Hyprland module already adds the
    # Hyprland portal, which handles compositor-specific requests such as screen
    # sharing. This block only adds the GTK portal fallback for generic desktop
    # requests Hyprland does not implement, such as the file picker.
    #
    # Plain English: portals are the bridge apps use to ask the desktop for
    # things like screen sharing, screenshots, and file pickers in a Wayland
    # session.
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
