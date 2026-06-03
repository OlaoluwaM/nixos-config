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
  # This is the Home Manager module that packages and starts the Quickshell UI.
  # "Home Manager" is the Nix tool that builds user-level config files,
  # user-level systemd services, and user-level packages.
  #
  # Plain English:
  # - The QML file draws the shell.
  # - The shell scripts gather data or perform actions.
  # - This Nix file packages those scripts, writes the generated Quickshell
  #   config, and starts the Quickshell service.
  #
  # Useful sources:
  # - Home Manager options: https://nix-community.github.io/home-manager/options.xhtml
  # - xdg.configFile option: https://nix-community.github.io/home-manager/options.xhtml#opt-xdg.configFile
  # - systemd.user.services option: https://nix-community.github.io/home-manager/options.xhtml#opt-systemd.user.services

  cfg = config.local.hyprland;
  commands = cfg.commands;
  theme = config.local.theme.colors;
  fonts = config.local.fonts;
  hyprlandSessionTarget = config.wayland.systemd.target;

  # writeShellApplication builds a real executable in the Nix store. runtimeInputs
  # are packages placed on PATH when that executable runs. This is why the shell
  # scripts can call commands like jq, sensors, and nmcli without using
  # hardcoded paths inside the scripts.
  powerProfileAdapterLib = pkgs.runCommandLocal "hypr-shell-power-profile-adapters" { } ''
    mkdir -p "$out/lib/hypr-shell-power-profile"
    cp ${./scripts/power-profile-adapters}/*.sh "$out/lib/hypr-shell-power-profile/"
  '';

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
    text = ''
      export HYPR_SHELL_POWER_PROFILE_LIB_DIR="${powerProfileAdapterLib}/lib/hypr-shell-power-profile"
      ${builtins.readFile ./scripts/hypr-shell-power-profile.sh}
    '';
  };

  caffeineScript = pkgs.writeShellApplication {
    name = "hypr-shell-caffeine";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/hypr-shell-caffeine.sh;
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
      iproute2
      jq
      lm_sensors
      networkmanager
      # hypr-shell-status.sh reads the active profile with `powerprofilesctl`
      # directly, so the daemon's CLI must be on PATH. (powerProfileScript below
      # only wraps the *write* path, not this read.)
      power-profiles-daemon
      caffeineScript
      powerProfileScript
      systemd
      util-linux
      wireguard-tools
    ];
    text = builtins.readFile ./scripts/hypr-shell-status.sh;
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

  # themeQml is the generated Theme.qml singleton. Colors come from
  # config.local.theme, fonts come from config.local.fonts, and geometry,
  # animation, and helper functions are static.
  themeQml = ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        id: root

        // ── Color palette (generated from local.theme) ──────────────────
        readonly property color base:           "${theme.base}"
        readonly property color surfaceVariant: "${theme.surfaceVariant}"
        readonly property color surfaceHover:   "${theme.surfaceHover}"
        readonly property color surfaceDeep:    "${theme.surfaceDeep}"
        readonly property color scrim:          "${theme.scrim}"
        readonly property color outline:        "${theme.outline}"
        readonly property color text:           "${theme.text}"
        readonly property color textSecondary:  "${theme.textSecondary}"
        readonly property color textDim:        "${theme.textDim}"
        readonly property color primary:        "${theme.primary}"
        readonly property color secondary:      "${theme.secondary}"
        readonly property color error:          "${theme.error}"
        readonly property color success:        "${theme.success}"
        readonly property color warning:        "${theme.warning}"
        readonly property color primaryForeground: "${theme.primaryForeground}"
        readonly property color secondaryForeground: "${theme.secondaryForeground}"
        readonly property color errorForeground: "${theme.errorForeground}"
        readonly property color metricCpu:      "${theme.metricCpu}"
        readonly property color metricMemory:   "${theme.metricMemory}"
        readonly property color metricTemperature: "${theme.metricTemperature}"

        // ── Fonts (generated from local.fonts) ──────────────────────────
        readonly property string fontFamily:     "${fonts.shell.family}"
        readonly property string monoFontFamily: "${fonts.mono.family}"

        // ── Type scale (px) ─────────────────────────────────────────────
        // The recurring text roles, named so panels/capsules stop hardcoding
        // the same pixel sizes. Values mirror what the UI already used; sizes
        // that appear only once or twice (one-offs) intentionally stay inline
        // rather than inflating this scale.
        readonly property int fontDisplay:   54   // big clock / battery readout
        readonly property int fontTitle:     22   // modal title, secondary readout
        readonly property int fontHeader:    16   // panel section headers
        readonly property int fontBody:      13   // capsule labels, default body
        readonly property int fontCaption:   12   // secondary captions
        readonly property int fontSmall:     11   // smallest labels

        // ── Capsule geometry ────────────────────────────────────────────
        readonly property int capsuleHeight:        46
        readonly property int capsuleRadius:        10
        readonly property int capsuleButtonSize:    34
        readonly property int capsuleButtonRadius:  8
        readonly property int popoverRadius:        20
        readonly property int cardRadius:           14
        readonly property int trackRadius:          3   // thin slider / progress bars

        // ── Animation durations (ms) ────────────────────────────────────
        readonly property int animFast:       150
        readonly property int animNormal:     300
        readonly property int animFade:       200

        // ── Easing vocabulary (all Easing.Bezier; pick the curve by motion role) ──
        readonly property int easingType: Easing.Bezier
        // standard — neutral motion: hover, colour fades, value changes (CSS "ease")
        readonly property list<real> easingCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
        // decel (ease-out) — entrances: an element appears and settles into place
        readonly property list<real> easingDecel: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
        // accel (ease-in) — exits: an element leaves and accelerates away
        readonly property list<real> easingAccel: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]

        // ── Capsule state helpers ───────────────────────────────────────
        // Uniform (active, hovered) signature; each responds to the state it needs:
        // fill washes with the accent when active, brightens on hover, border/text
        // shift to the accent when active.
        function capsuleColor(active, hovered) {
            // Active = a popover is open, or a radio/link is live. We wash the
            // base surface with a low-alpha primary tint rather than the solid-
            // primary fill used by the momentary toggles (caffeine/airplane):
            // connectivity is "on" most of the time, so a full accent fill would
            // make the bar loud. The tint reads as "live" while staying subtle;
            // hover deepens it slightly so the cursor still gives feedback.
            // Computed here so every capsule that sets `active` gets the same
            // treatment for free.
            if (active)
                return Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, hovered ? 0.26 : 0.18));
            return hovered ? surfaceHover : surfaceVariant;
        }

        function capsuleBorderColor(active, hovered) {
            return active ? primary : outline;
        }

        function capsuleTextColor(active, hovered) {
            return active ? primary : text;
        }

        // ── Active accent gradient (the "live radio/link" capsules: wifi/bt) ──
        // A soft primary→secondary wash that reads as "live" without the loud
        // solid fill of the momentary toggles. The stops tint the surface
        // (rather than using the raw accents) so the wash stays in-palette and
        // gentle; opaque so it composites over the capsule surface, not the
        // transparent bar window. Border and text for these capsules stay on
        // the standard accent helpers (capsuleBorderColor / capsuleTextColor).
        function capsuleGradientStart() {
            return Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, 0.22));
        }
        function capsuleGradientEnd() {
            return Qt.tint(surfaceVariant, Qt.rgba(secondary.r, secondary.g, secondary.b, 0.22));
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
    "@SHELL_COMMAND@"
    "@CAT_COMMAND@"
    "@AWK_COMMAND@"
    "@TR_COMMAND@"
    "@STATUS_SCRIPT@"
    "@TIMEZONE_SCRIPT@"
    "@NETWORK_COMMAND@"
    "@BLUETOOTH_COMMAND@"
    "@POWER_COMMAND@"
    "@REBOOT_COMMAND@"
    "@POWER_PROFILE_COMMAND@"
    "@CAFFEINE_COMMAND@"
    "@BRIGHTNESS_COMMAND@"
    "@LOCK_COMMAND@"
    "@SLEEP_COMMAND@"
    "@RFKILL_COMMAND@"
    "@LOGOUT_COMMAND@"
    "@NOTIFY_SEND_COMMAND@"
  ];

  commandReplacements = [
    "${pkgs.bash}/bin/sh"
    "${pkgs.coreutils}/bin/cat"
    "${pkgs.gawk}/bin/awk"
    "${pkgs.coreutils}/bin/tr"
    "${statusScript}/bin/hypr-shell-status"
    "${timezoneScript}/bin/hypr-shell-timezones"
    "${commands.airctl}/bin/airctl"
    "${unstable.overskride}/bin/overskride"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Shutting down...' --post-cmd '${pkgs.systemd}/bin/systemctl poweroff'"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Restarting...' --post-cmd '${pkgs.systemd}/bin/systemctl reboot'"
    "${powerProfileScript}/bin/hypr-shell-power-profile"
    "${caffeineScript}/bin/hypr-shell-caffeine"
    "${pkgs.brightnessctl}/bin/brightnessctl"
    "${pkgs.systemd}/bin/loginctl lock-session"
    "${pkgs.systemd}/bin/systemctl suspend"
    "${pkgs.util-linux}/bin/rfkill"
    "${unstable.hyprshutdown}/bin/hyprshutdown"
    "${pkgs.libnotify}/bin/notify-send"
  ];

  generatedCommandsQml = builtins.replaceStrings commandPlaceholders commandReplacements (
    builtins.readFile ./quickshell/GeneratedCommands.qml
  );

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
    # Quickshell-specific packages and generated helper scripts. Hyprland
    # compositor/session utilities live in default.nix.
    home.packages = with pkgs; [
      lm_sensors
      caffeineScript
      quickshell

      powerProfileScript
      statusScript
      timezoneScript
    ];

    xdg.configFile = {
      # Quickshell resolves sibling QML component types relative to the loaded
      # shell.qml. Keep the generated shell, generated theme, and copied
      # components in one managed directory so local types such as Bar and
      # Popovers are visible.
      "quickshell/hyprland".source = quickshellConfigDir;

      # Some desktop tools look at xdg-terminals.list to decide which terminal
      # app should be treated as the default.
      "xdg-terminals.list".text = "kitty.desktop\n";
    };

    # Ensure cache/state directories exist before helpers try to write small
    # files. Runtime command files under $XDG_RUNTIME_DIR are created by the
    # scripts themselves because that directory exists only inside a login
    # session.
    home.activation.ensureHyprShellDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.cacheHome}/hypr-shell" "${config.xdg.stateHome}/hypr-shell"
    '';

    # User-level systemd services for the Quickshell UI. These run as your user,
    # not as root. Home Manager's Hyprland module starts hyprland-session.target.
    # Quickshell starts with that target; the caffeine inhibitor starts on
    # demand and stops automatically when the Hyprland session target stops.
    systemd.user.services = {
      hypr-shell-quickshell = {
        Unit = {
          Description = "Minimal Hyprland Quickshell";
          After = [ hyprlandSessionTarget ];
          PartOf = [ hyprlandSessionTarget ];
        };

        Install.WantedBy = [ hyprlandSessionTarget ];

        Service = {
          # This is the command that starts the QML shell. The --config hyprland
          # part tells Quickshell to read ~/.config/quickshell/hyprland/shell.qml.
          ExecStart = "${pkgs.quickshell}/bin/quickshell --config hyprland";
          Restart = "on-failure";
        };
      };

      hypr-shell-caffeine = {
        Unit = {
          Description = "Manual Hypr Shell idle inhibitor";
          PartOf = [ hyprlandSessionTarget ];
        };

        Service = {
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block ${pkgs.coreutils}/bin/sleep infinity";
        };
      };
    };
  };
}
