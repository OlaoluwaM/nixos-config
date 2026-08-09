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

  # This script provides command-backed status data. Native Quickshell services
  # provide audio, media, and battery state directly inside QML.
  statusScript = pkgs.writeShellApplication {
    name = "hypr-shell-status";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
      gawk
      gnused
      iproute2
      jq
      networkmanager
      commands.caffeineScript
      # The active power profile is read via `hypr-shell-power-profile status`
      # (powerProfileScript), which carries its own power-profiles-daemon/asusctl
      # inputs, so the daemon CLI is not needed directly here. The script reads
      # temperature and brightness straight from sysfs, so lm_sensors and
      # brightnessctl are not needed either.
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

  # Reads display + keyboard backlight percents for the OSD. Keeps the brightness
  # read out of shell.qml so QML calls a single command instead of assembling a
  # brightnessctl | awk | tr pipeline inline.
  osdReadScript = pkgs.writeShellApplication {
    name = "hypr-shell-osd-read";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      gawk
    ];
    text = builtins.readFile ./scripts/hypr-shell-osd-read.sh;
  };

  # GeneratedTheme.qml contains only Nix-owned tokens. Theme.qml stays in the
  # editable QML tree and owns static geometry, animation, and helper functions.
  generatedThemeQml = ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        id: root

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

        readonly property string fontFamily:     "${fonts.shell.family}"
        readonly property string monoFontFamily: "${fonts.mono.family}"
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
    "@STATUS_SCRIPT@"
    "@TIMEZONE_SCRIPT@"
    "@OSD_READ_SCRIPT@"
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
    "${statusScript}/bin/hypr-shell-status"
    "${timezoneScript}/bin/hypr-shell-timezones"
    "${osdReadScript}/bin/hypr-shell-osd-read"
    "${commands.airctl}/bin/airctl"
    "${unstable.overskride}/bin/overskride"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Shutting down...' --post-cmd '${pkgs.systemd}/bin/systemctl poweroff'"
    "${unstable.hyprshutdown}/bin/hyprshutdown -t 'Restarting...' --post-cmd '${pkgs.systemd}/bin/systemctl reboot'"
    "${powerProfileScript}/bin/hypr-shell-power-profile"
    "${commands.caffeineScript}/bin/hypr-shell-caffeine"
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
    cp ${pkgs.writeText "hypr-shell-generated-theme.qml" generatedThemeQml} "$out/GeneratedTheme.qml"
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.backend == "quickshell") {
    # Quickshell-specific packages and generated helper scripts. Hyprland
    # compositor/session utilities live in default.nix.
    home.packages = with pkgs; [
      lm_sensors
      quickshell

      powerProfileScript
      statusScript
      timezoneScript
      osdReadScript
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
    # Quickshell starts with that target. Shared session helpers live in
    # default.nix.
    systemd.user.services = {
      hypr-shell-quickshell = {
        Unit = {
          Description = "Minimal Hyprland Quickshell";
          After = [ hyprlandSessionTarget ];
          PartOf = [ hyprlandSessionTarget ];
          Conflicts = [ "caffyne-shell.service" ];
        };

        Install.WantedBy = [ hyprlandSessionTarget ];

        Service = {
          # This is the command that starts the QML shell. The --config hyprland
          # part tells Quickshell to read ~/.config/quickshell/hyprland/shell.qml.
          ExecStart = "${pkgs.quickshell}/bin/quickshell --config hyprland";
          Restart = "on-failure";
        };
      };
    };
  };
}
