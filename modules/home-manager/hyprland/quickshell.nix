{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  # Beginner orientation for this file:
  #
  # This is the Home Manager module that wires the Hyprland ricing together.
  # "Home Manager" is the Nix tool that builds user-level config files,
  # user-level systemd services, and user-level packages.
  #
  # Plain English:
  # - The QML file draws the shell.
  # - The shell scripts gather data or perform actions.
  # - This Nix file packages those scripts, installs the tools they need, writes
  #   the generated ~/.config files, and starts the background services.
  #
  # Useful sources:
  # - Home Manager options: https://nix-community.github.io/home-manager/options.xhtml
  # - xdg.configFile option: https://nix-community.github.io/home-manager/options.xhtml#opt-xdg.configFile
  # - systemd.user.services option: https://nix-community.github.io/home-manager/options.xhtml#opt-systemd.user.services
  # - Hyprland keybinds: https://wiki.hypr.land/Configuring/Binds/
  # - Hyprland window rules: https://wiki.hypr.land/Configuring/Window-Rules/

  cfg = config.local.hyprland;
  theme = config.local.theme.colors;
  stripHash = s: lib.removePrefix "#" s;

  airctl = pkgs.callPackage ../../../pkgs/airctl { };

  # Wallpaper folder used by Waypaper. If WALLPAPERS_DIR is set in the session
  # environment, use that. Otherwise fall back to ~/Pictures/wallpapers.
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/wallpapers";

  # writeShellApplication builds a real executable in the Nix store. runtimeInputs
  # are packages placed on PATH when that executable runs. This is why the shell
  # scripts can call commands like jq, sensors, and nmcli without using
  # hardcoded paths inside the scripts.
  powerProfileScript = pkgs.writeShellApplication {
    name = "hypr-shell-power-profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.power-profiles-daemon

      # ASUS laptops expose extra platform-profile controls through asusctl.
      # The helper tries powerprofilesctl first, then asusctl as a fallback.
      unstable.asusctl
    ];
    text = builtins.readFile ./scripts/hypr-shell-power-profile.sh;
  };

  # This script provides command-backed status data. Native Quickshell services
  # provide audio, media, and battery state directly inside QML.
  statusScript = pkgs.writeShellApplication {
    name = "hypr-shell-status";
    runtimeInputs = with pkgs; [
      bluez
      brightnessctl
      coreutils
      findutils
      gawk
      gnused
      jq
      lm_sensors
      networkmanager
      powerProfileScript
    ];
    text = builtins.readFile ./scripts/hypr-shell-status.sh;
  };

  # Small command bridge used by keybinds. It writes a command into a runtime
  # file. shell.qml polls that file and reacts by opening the requested popover.
  popupScript = pkgs.writeShellApplication {
    name = "hypr-shell-popup";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = builtins.readFile ./scripts/hypr-shell-popup.sh;
  };

  # Separate time script for the center clock and calendar world-time cards.
  timezoneScript = pkgs.writeShellApplication {
    name = "hypr-shell-timezones";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = builtins.readFile ./scripts/hypr-shell-timezones.sh;
  };

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
      procps
      slurp
      wf-recorder
      libnotify
      xdg-utils
    ];
    text = builtins.readFile ./scripts/hypr-shell-screenrecord.sh;
  };

  # themeQml is the generated Theme.qml singleton. Colors come from
  # config.local.theme; geometry, animation, and helper functions are static.
  themeQml = ''
    pragma Singleton

    import QtQuick

    QtObject {

        // ── Color palette (generated from local.theme) ──────────────────
        readonly property color base:           "${theme.base}"
        readonly property color surfaceVariant: "${theme.surfaceVariant}"
        readonly property color surfaceHover:   "${theme.surfaceHover}"
        readonly property color outline:        "${theme.outline}"
        readonly property color text:           "${theme.text}"
        readonly property color textSecondary:  "${theme.textSecondary}"
        readonly property color textDim:        "${theme.textDim}"
        readonly property color primary:        "${theme.primary}"
        readonly property color secondary:      "${theme.secondary}"
        readonly property color tertiary:       "${theme.tertiary}"
        readonly property color error:          "${theme.error}"
        readonly property color success:        "${theme.success}"
        readonly property color warning:        "${theme.warning}"
        readonly property color primaryForeground: "${theme.primaryForeground}"
        readonly property color secondaryForeground: "${theme.secondaryForeground}"
        readonly property color tertiaryForeground: "${theme.tertiaryForeground}"
        readonly property color errorForeground: "${theme.errorForeground}"
        readonly property color metricCpu:      "${theme.metricCpu}"
        readonly property color metricMemory:   "${theme.metricMemory}"
        readonly property color metricTemperature: "${theme.metricTemperature}"

        // ── Capsule geometry ────────────────────────────────────────────
        readonly property int capsuleHeight:        46
        readonly property int capsuleRadius:        10
        readonly property int capsuleButtonSize:    34
        readonly property int capsuleButtonRadius:  8
        readonly property int popoverRadius:        20
        readonly property int cardRadius:           14

        // ── Animation durations (ms) ────────────────────────────────────
        readonly property int animFast:       150
        readonly property int animNormal:     300
        readonly property int animFade:       200

        // ── Default easing (CSS "ease") ─────────────────────────────────
        readonly property int easingType: Easing.Bezier
        readonly property list<real> easingCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]

        // ── Capsule state helpers ───────────────────────────────────────
        function capsuleColor(active, hovered) {
            return surfaceVariant;
        }

        function capsuleBorderColor(active, hovered) {
            if (active)  return primary;
            if (hovered) return surfaceHover;
            return outline;
        }

        function capsuleTextColor(active, hovered) {
            if (active)  return primary;
            if (hovered) return text;
            return text;
        }
    }
  '';

  # GeneratedCommands.qml is the final command/config singleton written to
  # ~/.config/quickshell/hyprland.
  #
  # GeneratedCommands.qml contains placeholders like @STATUS_SCRIPT@ instead of
  # hardcoded paths. replaceStrings swaps those placeholders for exact Nix store
  # paths.
  # This matters because Nix packages live at long immutable paths such as
  # /nix/store/.../bin/brightnessctl, not simply /usr/bin/brightnessctl.
  commandPlaceholders = [
    "@STATUS_SCRIPT@"
    "@TIMEZONE_SCRIPT@"
    "@VICINAE_COMMAND@"
    "@NETWORK_COMMAND@"
    "@BLUETOOTH_COMMAND@"
    "@POWER_COMMAND@"
    "@REBOOT_COMMAND@"
    "@POWER_PROFILE_COMMAND@"
    "@BRIGHTNESS_COMMAND@"
    "@LOCK_COMMAND@"
    "@SLEEP_COMMAND@"
    "@REFRESH_COMMAND@"
    "@RFKILL_COMMAND@"
    "@LOGOUT_COMMAND@"
    "@NOTIFY_SEND_COMMAND@"
  ];

  commandReplacements = [
    "${statusScript}/bin/hypr-shell-status"
    "${timezoneScript}/bin/hypr-shell-timezones"
    "${pkgs.vicinae}/bin/vicinae"
    "${airctl}/bin/airctl"
    "${unstable.overskride}/bin/overskride"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"
    "${powerProfileScript}/bin/hypr-shell-power-profile"
    "${pkgs.brightnessctl}/bin/brightnessctl"
    "${pkgs.systemd}/bin/loginctl lock-session"
    "${pkgs.systemd}/bin/systemctl suspend"
    "${pkgs.hyprland}/bin/hyprctl reload"
    "${pkgs.util-linux}/bin/rfkill"
    "${unstable.hyprshutdown}/bin/hyprshutdown"
    "${pkgs.libnotify}/bin/notify-send"
  ];

  generatedCommandsQml =
    builtins.replaceStrings
      commandPlaceholders
      commandReplacements
      (builtins.readFile ./quickshell/GeneratedCommands.qml);

  quickshellConfigDir = pkgs.runCommandLocal "hypr-shell-quickshell-config" { } ''
    mkdir -p "$out"
    cp -R ${./quickshell}/. "$out/"
    chmod -R u+w "$out"
    cp ${pkgs.writeText "hypr-shell-generated-commands.qml" generatedCommandsQml} "$out/GeneratedCommands.qml"
    cp ${pkgs.writeText "hypr-shell-theme.qml" themeQml} "$out/Theme.qml"
  '';
in
{
  config = lib.mkIf cfg.enable {
    # Packages installed into the user environment when local.hyprland.enable is
    # true. Some are visible apps, some are CLI helpers used by scripts, and some
    # are the scripts defined above.
    home.packages = with pkgs; [
      unstable.overskride
      unstable.awww
      brightnessctl

      # cliphist is intentionally commented out. Vicinae already provides
      # clipboard history through its own UI. Keeping this commented preserves
      # the old standalone clipboard option without running two clipboard
      # managers at once.
      # cliphist
      grim
      jq
      libnotify
      lm_sensors
      mission-center
      airctl
      quickshell
      satty
      slurp
      vicinae
      unstable.waypaper
      wl-clipboard
      unstable.hyprshutdown

      powerProfileScript
      popupScript
      statusScript
      timezoneScript
      screenshotScript
      screenrecordScript

      wf-recorder
    ];

    home.sessionVariables = {
      # Helps Chromium/Electron apps prefer Wayland behavior under NixOS.
      NIXOS_OZONE_WL = "1";
    };

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

    xdg.configFile = {
      # Quickshell resolves sibling QML component types relative to the loaded
      # shell.qml. Keep the generated shell, generated theme, and copied
      # components in one managed directory so local types such as Bar and
      # Popovers are visible.
      "quickshell/hyprland".source = quickshellConfigDir;

      # Some desktop tools look at xdg-terminals.list to decide which terminal
      # app should be treated as the default.
      "xdg-terminals.list".text = "kitty.desktop\n";

      # Waypaper is the wallpaper picker. awww is the background daemon that
      # actually draws the wallpaper on the Wayland outputs.
      "waypaper/config.ini".text = ''
        [Settings]
        language = en
        folder = ${wallpapersDir}
        backend = awww
        monitors = All
        fill = Fill
        sort = name
        color = #000000
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

      # Writes the Hyprland config to:
      #   ~/.config/hypr/hyprland.conf
      #
      # The text below is Hyprland's own config language, embedded inside Nix.
      # Nix interpolation like ${pkgs.vicinae}/bin/vicinae is resolved first,
      # then Hyprland reads the final plain text file.
      "hypr/hyprland.conf".text = ''
        # Monitor rule. Blank monitor name means "apply to all monitors".
        # preferred = use the monitor's preferred resolution/refresh rate.
        # auto = let Hyprland choose the position.
        # 1 = scale factor.
        monitor=,preferred,auto,1

        # Environment variables exported into the Hyprland session.
        env = XDG_CURRENT_DESKTOP,Hyprland
        env = XDG_SESSION_DESKTOP,Hyprland
        env = NIXOS_OZONE_WL,1

        # exec-once starts long-running services once when Hyprland starts.
        # Use exec-once for daemons; use normal exec only for commands that
        # should run every time the config reloads.
        #
        # Source: https://wiki.hypr.land/Configuring/Keywords/
        exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE WALLPAPERS_DIR
        exec-once = systemctl --user start hypr-shell-awww.service
        exec-once = systemctl --user start hypr-shell-waypaper-restore.service
        exec-once = systemctl --user start hypr-shell-quickshell.service
        exec-once = systemctl --user start hypr-shell-vicinae.service

        # Standalone clipboard service is intentionally commented out because
        # Vicinae handles clipboard history. Uncomment this only if you want
        # cliphist/wl-paste clipboard collection back.
        # exec-once = systemctl --user start hypr-shell-clipboard.service
        exec-once = systemctl --user start hypridle.service
        exec-once = systemctl --user start hyprpolkitagent.service
        exec-once = systemctl --user start hyprsunset.service
        exec-once = systemctl --user start udiskie.service

        input {
          # Keyboard layout and touchpad defaults.
          kb_layout = us
          follow_mouse = 1
          touchpad {
            natural_scroll = true
          }
        }

        general {
          # Window gaps and borders. This affects normal app windows, not the
          # Quickshell top-bar capsules.
          gaps_in = 4
          gaps_out = 8
          border_size = 2
          col.active_border = rgb(${stripHash theme.secondary})
          col.inactive_border = rgb(${stripHash theme.outline})
          layout = dwindle
        }

        decoration {
          # Window rounding, blur, and shadow for regular Hyprland windows.
          rounding = 10
          blur {
            enabled = true
            size = 5
            passes = 2
          }
          shadow {
            enabled = true
            range = 12
            render_power = 2
            color = rgba(${stripHash theme.shadowColor})
          }
        }

        animations {
          # Hyprland window/workspace animations. These do not animate QML
          # internals; they affect window manager transitions.
          enabled = true
          bezier = easeOut, 0.22, 1, 0.36, 1
          animation = windows, 1, 3, easeOut
          animation = border, 1, 4, default
          animation = fade, 1, 3, easeOut
          animation = workspaces, 1, 3, easeOut
        }

        dwindle {
          pseudotile = true
          preserve_split = true
        }

        misc {
          # Cosmetic/behavior settings for the Hyprland session itself.
          disable_hyprland_logo = true
          disable_splash_rendering = true
          focus_on_activate = true
        }

        # Window rules force certain apps to open floating/centered/sized.
        # These are especially useful for launcher/control-panel style apps.
        windowrulev2 = float,class:^(vicinae)$
        windowrulev2 = center,class:^(vicinae)$
        windowrulev2 = size 42% 48%,class:^(vicinae)$
        windowrulev2 = float,class:^(io.github.airctl)$
        windowrulev2 = float,class:^(io.github.kaii_lb.Overskride)$
        windowrulev2 = float,class:^(mission-center)$

        $mod = SUPER
        $terminal = kitty

        # Keybinds. Format is roughly:
        #   bind = modifiers, key, action, argument
        # Source: https://wiki.hypr.land/Configuring/Binds/
        bind = $mod, Return, exec, $terminal
        bindr = $mod, SUPER_L, exec, ${pkgs.vicinae}/bin/vicinae open
        bindr = $mod, SUPER_R, exec, ${pkgs.vicinae}/bin/vicinae open
        bind = $mod, Space, exec, ${pkgs.vicinae}/bin/vicinae open
        bind = $mod SHIFT, V, exec, ${pkgs.vicinae}/bin/vicinae 'vicinae://launch/clipboard/history?toggle=true'

        # Wallpaper and screenshot helpers from this module.
        bind = $mod SHIFT, W, exec, ${unstable.waypaper}/bin/waypaper
        # Random wallpaper is wired but intentionally left unbound until a key
        # is chosen for it.
        # bind = $mod SHIFT, ?, exec, ${unstable.waypaper}/bin/waypaper --random
        bind = , F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot area
        bind = SHIFT, F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot full
        bind = CTRL, F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot window
        bind = $mod SHIFT, R, exec, ${screenrecordScript}/bin/hypr-shell-record area
        bind = $mod CTRL, R, exec, ${screenrecordScript}/bin/hypr-shell-record full
        bind = $mod ALT, R, exec, ${screenrecordScript}/bin/hypr-shell-record stop
        bind = $mod, E, exec, ${pkgs.nautilus}/bin/nautilus
        bind = $mod, Q, exec, ${popupScript}/bin/hypr-shell-popup quick-settings
        bind = $mod, N, exec, ${airctl}/bin/airctl
        bind = $mod, B, exec, ${unstable.overskride}/bin/overskride
        bind = $mod, M, exec, ${pkgs.mission-center}/bin/missioncenter
        bind = $mod, Escape, exec, ${unstable.hyprshutdown}/bin/hyprshutdown
        bind = , XF86PowerOff, exec, ${unstable.hyprshutdown}/bin/hyprshutdown

        # Volume keys route through Quickshell so PipeWire stays the audio API.
        bindel = , XF86AudioRaiseVolume, exec, ${popupScript}/bin/hypr-shell-popup audio-up
        bindel = , XF86AudioLowerVolume, exec, ${popupScript}/bin/hypr-shell-popup audio-down
        bindl = , XF86AudioMute, exec, ${popupScript}/bin/hypr-shell-popup audio-mute

        # Brightness keys
        bindel = , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+ && ${popupScript}/bin/hypr-shell-popup osd-brightness
        bindel = , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%- && ${popupScript}/bin/hypr-shell-popup osd-brightness

        # Keyboard backlight keys
        bindel = , XF86KbdBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl -d '*::kbd_backlight' set 5%+ && ${popupScript}/bin/hypr-shell-popup osd-keyboard
        bindel = , XF86KbdBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl -d '*::kbd_backlight' set 5%- && ${popupScript}/bin/hypr-shell-popup osd-keyboard

        # Lock through loginctl rather than calling hyprlock directly. hypridle
        # is configured to respond to lock-session with hyprlock.
        bind = $mod, L, exec, ${pkgs.systemd}/bin/loginctl lock-session
        bind = $mod SHIFT, Q, killactive,
        bind = ALT, F4, killactive,
        bind = $mod, F, fullscreen,
        bind = $mod, V, togglefloating,

        bindm = $mod, mouse:272, movewindow
        bindm = $mod, mouse:273, resizewindow

        # Workspace keybinds. SUPER+1 switches to workspace 1.
        # SUPER+SHIFT+1 moves the current window to workspace 1.
        bind = $mod, 1, workspace, 1
        bind = $mod, 2, workspace, 2
        bind = $mod, 3, workspace, 3
        bind = $mod, 4, workspace, 4
        bind = $mod, 5, workspace, 5
        bind = $mod SHIFT, 1, movetoworkspace, 1
        bind = $mod SHIFT, 2, movetoworkspace, 2
        bind = $mod SHIFT, 3, movetoworkspace, 3
        bind = $mod SHIFT, 4, movetoworkspace, 4
        bind = $mod SHIFT, 5, movetoworkspace, 5
      '';

    };

    services.hyprpolkitagent.enable = true;

    # hyprsunset shifts the display color temperature later in the day. Lower
    # temperature values look warmer/oranger. This is separate from the QML UI.
    services.hyprsunset = {
      enable = true;
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

    # Ensure runtime/cache directories exist before scripts try to write state.
    # "state" means long-lived small data such as the chosen wallpaper path.
    # "cache" means generated/recoverable files such as the lock wallpaper link.
    home.activation.ensureHyprShellDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.cacheHome}/hypr-shell" "${config.xdg.stateHome}/hypr-shell"
    '';

    # User-level systemd services. These run as your user, not as root. Hyprland
    # starts them via exec-once lines above.
    systemd.user.services = {
      hypr-shell-awww = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${unstable.awww}/bin/awww-daemon";
          Restart = "on-failure";
        };
      };

      hypr-shell-waypaper-restore = {
        Unit = {
          Description = "Restore Waypaper wallpaper";
          After = [ "hypr-shell-awww.service" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${unstable.waypaper}/bin/waypaper --restore";
          Environment = [ "WALLPAPERS_DIR=${wallpapersDir}" ];
        };
      };

      hypr-shell-quickshell = {
        Unit = {
          Description = "Minimal Hyprland Quickshell";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          # This is the command that starts the QML shell. The --config hyprland
          # part tells Quickshell to read ~/.config/quickshell/hyprland/shell.qml.
          ExecStart = "${pkgs.quickshell}/bin/quickshell --config hyprland";
          Restart = "on-failure";
          Environment = [ "WALLPAPERS_DIR=${wallpapersDir}" ];
        };
      };

      hypr-shell-vicinae = {
        Unit = {
          Description = "Vicinae launcher service";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server";
          Restart = "on-failure";
          Environment = [
            "USE_LAYER_SHELL=1"
            "WALLPAPERS_DIR=${wallpapersDir}"
          ];
        };
      };

      # hypr-shell-clipboard = {
      #   This whole service is commented out on purpose. It would watch the
      #   Wayland clipboard and store entries through cliphist. Since Vicinae is
      #   already configured as the launcher/clipboard UI, running this as well
      #   would be redundant unless you explicitly want cliphist back.
      #   Unit = {
      #     Description = "Clipboard history collector";
      #     After = [ "graphical-session.target" ];
      #     PartOf = [ "graphical-session.target" ];
      #   };
      #
      #   Service = {
      #     ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      #     Restart = "on-failure";
      #   };
      # };
    };
  };
}
