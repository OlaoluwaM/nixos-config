{
  config,
  hostConfig,
  inputs,
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
# - default.nix: compositor config, session target, wallpaper/session
#   plumbing, shared packages, portals
# - keybindings.nix: every Hyprland key chord
# - hyprlock.nix: lock-screen look and behavior
# - hypridle.nix: idle locking behavior
#
# This is currently a stock Hyprland profile: no bar, no shell UI. The
# previous desktop shell stack was removed as a clean-slate teardown ahead of
# a new silere-shell integration.
#
# Home Manager source/options:
# https://nix-community.github.io/home-manager/options.xhtml
let
  cfg = config.local.hyprland;
  commands = cfg.commands;
  theme = config.local.theme.colors;
  stripHash = s: lib.removePrefix "#" s;
  hyprlandSessionTarget = "hyprland-session.target";
  # Local copies used only by the `on = hyprland.shutdown` handler below.
  # keybindings.nix keeps its own copies for its binds; small duplication
  # between sibling modules is fine, cross-module coupling is not.
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;

  # Wallpaper folder for the (future) wallpaper pipeline. If WALLPAPERS_DIR is
  # set in the session environment, use that. Otherwise fall back to
  # ~/Pictures/wallpapers.
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/wallpapers";

  # Keep the built-in default at a stable path outside any particular shell's
  # own config directory. hyprlock reads this same path, so the lock screen
  # must not depend on any shell being active before its background exists.
  defaultWallpaperConfigPath = "hypr/wallpapers/default.png";
  defaultWallpaper = "${config.xdg.configHome}/${defaultWallpaperConfigPath}";

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
  # Import the focused modules that make up the Hyprland session.
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ./keybindings.nix
    ../vicinae.nix
  ];

  options.local.hyprland = {
    # Creates the option local.hyprland.enable. Other files can set this to true
    # to enable the whole Home Manager Hyprland profile.
    enable = lib.mkEnableOption "Hyprland configuration";

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = defaultWallpaper;
      description = ''
        Stable wallpaper path shared by the desktop shell and hyprlock. Prefer
        a Home Manager path over a versioned Nix store path so applications can
        persist the value without retaining an obsolete store generation.
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
    # These live under local.hyprland because they belong to the whole
    # Hyprland session: default.nix uses them for packages, and
    # keybindings.nix reads them across module boundaries for keybinds.
    # `internal = true` marks these as shared values for the Hyprland module
    # files in this directory, not settings users are expected to
    # configure/set directly.
    commands = {
      caffeineScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Manual idle-inhibitor helper used by the Hyprland session.";
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
        caffeineScript
        screenshotScript
        screenrecordScript
        ;
    };

    local.vicinae.enable = true;
    local.vicinae.systemd.target = hyprlandSessionTarget;

    # Tells Home Manager which user systemd target represents "the Hyprland
    # desktop session is running." Services such as hypridle, hyprsunset, and
    # Vicinae attach themselves to this same target, so they start when
    # Hyprland starts and stop when the Hyprland session stops. Without one
    # shared target, each service would need its own separate start/stop
    # rules and they could drift out of sync.
    wayland.systemd.target = hyprlandSessionTarget;

    # WALLPAPERS_DIR is set via home.sessionVariables (modules/home-manager/
    # dotfiles.nix), which only lands in
    # ~/.nix-profile/etc/profile.d/hm-session-vars.sh. Nothing sources that
    # file for this greetd-launched session: there is no ~/.profile, greetd's
    # worker only tries /etc/profile and $HOME/.profile before exec'ing
    # start-hyprland, and start-hyprland is an ELF binary, not a shell
    # script, so it can never source anything either.
    #
    # Setting it here instead makes Home Manager write it into
    # ~/.config/environment.d/, which every unit the systemd user manager
    # starts inherits, without needing a per-unit Environment= line. The
    # variable is not consumed by anything yet -- there is no shell UI in this
    # profile right now -- but it stays set because the upcoming wallpaper
    # pipeline stage reads it.
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
      # as hypridle, hyprsunset, and Vicinae, need these values to know which
      # Wayland/Hyprland session they belong to. Without them, those services
      # can start but fail to talk to the compositor, portals, or the right
      # display.
      systemd = {
        enable = true;
        variables = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_DESKTOP"
          "XDG_SESSION_TYPE"
          # Repo-specific: reserved for the upcoming wallpaper pipeline stage.
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
            match.class = "^(mission-center)$";
            float = true;
          }
        ];
      };
    };

    # Baseline user packages for the Hyprland profile. These are not all visible
    # apps; some are fonts and Qt support libraries that make the UI render
    # correctly.
    home.packages = with pkgs; [
      # General font/icon support. This is a stock Hyprland profile with no
      # shell UI, so nothing here depends on Nerd Font glyph icons. The
      # symbols font is kept as a broad fallback for terminal/app text that
      # may still contain those characters. Noto (incl. color emoji) comes
      # from the fontconfig module, which owns the fallback fonts for every
      # profile.
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
    ];

    # Everyday file-type defaults for the Hyprland session, merged into the
    # xdg.mimeApps set that desktop.nix enables. GNOME gets these as stock
    # desktop defaults; outside GNOME they must be declared, or xdg-open falls
    # back to whatever app happens to advertise the type (opening a directory
    # in VS Code, say). Loupe, Papers, and Nautilus are installed above; VLC
    # and Gapless come from home.packages.
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

    xdg.configFile = {
      # Provision a default image even in a clean VM: hyprlock requires a real
      # image at this stable path even on first boot, before any shell or
      # wallpaper picker has run. This nixos-artwork wallpaper is an interim
      # placeholder until the wallpaper pipeline stage lands. The public
      # option points at this stable link by default; users can override it
      # with another durable path without changing the modules that consume
      # the wallpaper.
      ${defaultWallpaperConfigPath}.source =
        pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath;
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
    # temperature values look warmer/oranger. This is shared session
    # infrastructure, independent of whatever shell UI eventually lands.
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
    # Manager modules in this config.
    systemd.user.services = {
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

      # Manual Caffeine is shared session infrastructure; hypridle respects
      # its systemd idle inhibitor.
      hypr-shell-caffeine = {
        Unit = {
          Description = "Manual Hyprland idle inhibitor";
          PartOf = [ hyprlandSessionTarget ];
        };

        Service = {
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block ${pkgs.coreutils}/bin/sleep infinity";
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
