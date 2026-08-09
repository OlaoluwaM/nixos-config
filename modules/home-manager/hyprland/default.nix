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
  useCaffyne = cfg.enable && cfg.shell.backend == "caffyne";
  useQuickshell = cfg.enable && cfg.shell.backend == "quickshell";

  vicinaeCommand = lib.getExe' config.programs.vicinae.package "vicinae";
  caffyneActionCommand = lib.getExe commands.caffyneAction;
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

  airctl = pkgs.callPackage ../../../pkgs/airctl { };

  # Wallpaper folder used by Waypaper. If WALLPAPERS_DIR is set in the session
  # environment, use that. Otherwise fall back to ~/Pictures/wallpapers.
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/wallpapers";

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

  caffeineScript = pkgs.writeShellApplication {
    name = "hypr-shell-caffeine";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/hypr-shell-caffeine.sh;
  };
in
{
  # Import the focused modules that make up the riced Hyprland session.
  imports = [
    ./caffyne.nix
    ./hypridle.nix
    ./hyprlock.nix
    ../vicinae.nix
    ./quickshell.nix
  ];

  options.local.hyprland = {
    # Creates the option local.hyprland.enable. Other files can set this to true
    # to enable the whole Home Manager Hyprland profile.
    enable = lib.mkEnableOption "Hyprland configuration";

    shell.backend = lib.mkOption {
      type = lib.types.enum [
        "caffyne"
        "quickshell"
      ];
      default = "caffyne";
      description = ''
        Desktop shell backend for the Hyprland session. The backends are
        mutually exclusive so only one bar, notification server, OSD, and
        wallpaper integration runs at a time. Idle and lock services are shared.
      '';
    };

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
      caffyneAction = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Narrow Caffyne D-Bus action helper used by Hyprland keybinds.";
      };

      caffeineScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Shared manual idle-inhibitor helper used by both shell backends.";
      };

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
        caffeineScript
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

    # WALLPAPERS_DIR is set via home.sessionVariables (modules/home-manager/
    # dotfiles.nix), which only lands in
    # ~/.nix-profile/etc/profile.d/hm-session-vars.sh. Nothing sources that
    # file for this greetd-launched session: there is no ~/.profile, greetd's
    # worker only tries /etc/profile and $HOME/.profile before exec'ing
    # start-hyprland, and start-hyprland is an ELF binary, not a shell
    # script, so it can never source anything either. Without this, Caffyne's
    # wallpaper picker (windows/dash/wallpapers.py in
    # caffyne-runtime-integration.patch) reads os.environ, finds
    # WALLPAPERS_DIR unset, and silently falls back to the read-only bundled
    # wallpapers under the Nix store.
    #
    # Setting it here instead makes Home Manager write it into
    # ~/.config/environment.d/, which every unit the systemd user manager
    # starts inherits -- including caffyne-shell.service -- without needing
    # a per-unit Environment= line.
    #
    # Caveat: environment.d is only read when the systemd user manager itself
    # starts, not on every `home-manager switch`. An already-running session
    # will not pick this up until the next login.
    systemd.user.sessionVariables.WALLPAPERS_DIR = wallpapersDir;

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

          (mkBind "${mod} + M" (execDispatcher (lib.getExe pkgs.protonmail-desktop)))
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
        ]
        ++ lib.optionals useQuickshell [
          (mkBind "${mod} + SHIFT + W" (execDispatcher "${unstable.waypaper}/bin/waypaper"))

          # Hyprland owns the key chords while Quickshell owns these named
          # actions and their hold-repeat behavior.
          (mkBind "${mod} + Q" "hl.dsp.global(\"quickshell:quickSettings\")")
          (mkBind "${mod} + ALT + W" (execDispatcher "${commands.airctl}/bin/airctl"))
          (mkBind "${mod} + B" (execDispatcher "${unstable.overskride}/bin/overskride"))
          (mkBind "${mod} + Escape" (execDispatcher "${unstable.hyprshutdown}/bin/hyprshutdown"))
          (mkBind "XF86PowerOff" (execDispatcher "${unstable.hyprshutdown}/bin/hyprshutdown"))
          (mkBindWithFlags "XF86AudioRaiseVolume" "hl.dsp.global(\"quickshell:audioUp\")" {
            locked = true;
          })
          (mkBindWithFlags "XF86AudioLowerVolume" "hl.dsp.global(\"quickshell:audioDown\")" {
            locked = true;
          })
          (mkBindWithFlags "XF86AudioMute" "hl.dsp.global(\"quickshell:audioMute\")" {
            locked = true;
          })
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
        ]
        ++ lib.optionals useCaffyne [
          (mkBind "${mod} + SHIFT + W" (execDispatcher "${caffyneActionCommand} wallpapers"))
          (mkBind "${mod} + Q" (execDispatcher "${caffyneActionCommand} settings"))
          (mkBind "${mod} + ALT + W" (execDispatcher "${caffyneActionCommand} wifi"))
          (mkBind "${mod} + B" (execDispatcher "${caffyneActionCommand} bluetooth"))
          (mkBind "${mod} + Escape" (execDispatcher "${caffyneActionCommand} session"))
          (mkBind "XF86PowerOff" (execDispatcher "${caffyneActionCommand} session"))
          # Direct device commands keep hardware keys usable while locked.
          # Caffyne observes PipeWire and backlight changes and owns the OSD.
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
        ++ lib.optionals enableAsusRogKeybindings [
          (mkBind "XF86Launch1" (execDispatcher (lib.getExe' unstable.asusctl "rog-control-center")))
          (mkBind "F5" (execDispatcher "${lib.getExe' unstable.asusctl "asusctl"} profile -n"))
        ];
      };
    };

    # Baseline user packages for the Hyprland profile. These are not all visible
    # apps; some are fonts and Qt support libraries that make the UI render
    # correctly.
    home.packages =
      (with pkgs; [
        # General font/icon support. The Quickshell bar should not depend on Nerd
        # Font glyph icons; it uses SVG icons instead. The symbols font is kept as
        # a broad fallback for terminal/app text that may still contain those
        # characters outside this shell. Noto (incl. color emoji) comes from the
        # fontconfig module, which owns the fallback fonts for every profile.
        font-awesome
        nerd-fonts.symbols-only

        nautilus

        # Hyprland session utilities and apps launched by the keybinds above.
        brightnessctl
        commands.caffeineScript
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
        wayland-pipewire-idle-inhibit
        wf-recorder
      ])
      ++ lib.optionals useQuickshell (
        with pkgs;
        [
          # Qt Wayland/QML support belongs to the Quickshell rollback backend.
          libsForQt5.qtwayland
          qt6.qtdeclarative
          qt6.qtimageformats
          qt6.qtsvg
          qt6.qtwayland

          commands.airctl
          unstable.awww
          unstable.hyprshutdown
          unstable.overskride
          unstable.waypaper
        ]
      );

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

    # Waypaper remains part of the Quickshell rollback backend. Caffyne owns
    # wallpaper selection and awww when its backend is selected.
    xdg.desktopEntries = lib.mkIf useQuickshell {
      waypaper = {
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
    };

    # Waypaper is the wallpaper picker. awww is the background daemon that
    # actually draws the wallpaper on the Wayland outputs.
    xdg.configFile = lib.mkIf useQuickshell {
      "waypaper/config.ini".text = ''
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

      '';
    };

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
    #
    # Shared session infrastructure under both shell backends, not just
    # Quickshell: Caffyne's Quick Settings night-mode tile is a thin control
    # over this same unit (services/night_mode.py in
    # caffyne-hypridle-hyprlock.patch) rather than owning its own wlsunset
    # process, mirroring how the Caffeine tile controls
    # hypr-shell-caffeine.service instead of doing the work itself.
    #
    # The endpoints mirror the GNOME profile this replaces (neutral during
    # the day, 2467K overnight -- see modules/home-manager/gnome/default.nix:
    # org/gnome/settings-daemon/plugins/color, from = 19.0, to = 8.0,
    # temperature = 2467). hyprsunset applies each profile entry abruptly and
    # has no native fade, so the 19:00 and 19:30 entries step the temperature
    # down across the hour after GNOME's configured start time instead of
    # jumping straight to 2467K.
    services.hyprsunset = {
      enable = true;
      systemdTarget = hyprlandSessionTarget;
      settings = {
        profile = [
          {
            time = "8:00";
            identity = true;
          }
          {
            time = "19:00";
            temperature = 4500;
          }
          {
            time = "19:30";
            temperature = 3500;
          }
          {
            time = "20:00";
            temperature = 2467;
          }
        ];
      };
    };

    # Extra Hyprland-session user services that do not have dedicated Home
    # Manager modules in this config. The media inhibitor is backend-neutral;
    # Waypaper and its awww daemon belong only to the Quickshell rollback path.
    systemd.user.services = {
      # Block idle while PipeWire reports active media playback, so videos,
      # calls, and similar media do not let the selected idle manager lock the
      # session.
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

      # Manual Caffeine is shared session infrastructure. Both shell backends
      # control this unit, and hypridle respects its systemd idle inhibitor.
      hypr-shell-caffeine = {
        Unit = {
          Description = "Manual Hyprland idle inhibitor";
          PartOf = [ hyprlandSessionTarget ];
        };

        Service = {
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block ${pkgs.coreutils}/bin/sleep infinity";
        };
      };
    }
    // lib.optionalAttrs useQuickshell {
      # awww is the wallpaper backend daemon. Waypaper chooses the wallpaper,
      # but awww is the process that actually draws it on the Wayland outputs.
      hypr-shell-awww = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          # Same ordering fix as caffyne-awww in caffyne.nix: without this,
          # sd-switch/systemd is free to start awww before the Hyprland
          # session target is up, where it fails against no compositor and
          # burns through its restart budget.
          After = [ hyprlandSessionTarget ];
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
