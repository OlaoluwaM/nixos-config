{
  config,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# This module packages the shared helper scripts other Hyprland modules
# launch (screenshot, screenrecord, manual caffeine/idle-inhibit toggle, the
# silere-lock wrapper every session lock goes through) and
# declares the local.hyprland.commands option tree those modules read them
# back from. See the long comment on that option block below for why it
# exists as an option tree instead of a plain `let` value.
let
  cfg = config.local.hyprland;

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
    text = builtins.readFile ../scripts/hypr-shell-screenshot.sh;
  };

  screenrecordScript = pkgs.writeShellApplication {
    name = "hypr-shell-record";
    runtimeInputs = with pkgs; [
      coreutils
      # gpu-screen-recorder's KMS capture needs the setcap gsr-kms-server
      # wrapper granted by programs.gpu-screen-recorder.enable (see
      # hosts/boreas/default.nix) -- this only puts the CLI on PATH.
      gpu-screen-recorder
      # hyprctl + jq: the window mode derives its capture geometry from the
      # active window the same way screenshotScript's window mode does.
      hyprland
      jq
      libnotify
      procps
      slurp
      xdg-utils
    ];
    text = builtins.readFile ../scripts/hypr-shell-screenrecord.sh;
  };

  caffeineScript = pkgs.writeShellApplication {
    name = "hypr-shell-caffeine";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      # `qs ipc` for the preset-aware toggle path. Same package silere.nix's
      # service runs the shell with, so the CLI can never skew from the
      # instance it is calling into.
      cfg.commands.quickshellPackage
    ];
    # `qs ipc` locates the running instance by config path, and the shell
    # runs from a store path via -p, not the default config dir -- a bare
    # `qs ipc call` finds nothing and the script silently fell back to raw
    # unit control (losing the preset). The script reads this variable to
    # target the exact packaged shell.qml the service runs.
    runtimeEnv.SILERE_SHELL_QML = "${cfg.commands.silereShellPackage}/share/silere-shell/shell.qml";
    text = builtins.readFile ../scripts/hypr-shell-caffeine.sh;
  };

  # hypridle's lock_cmd and the shell menu's Lock target. Its header comment
  # holds the rules it keeps.
  lockScript = pkgs.writeShellApplication {
    name = "silere-lock";
    runtimeInputs = [
      pkgs.coreutils
      # hyprctl: whether the session reads locked.
      pkgs.hyprland
      config.programs.hyprlock.package
      # pgrep: a hyprlock started outside the wrapper.
      pkgs.procps
      # systemd-run for the lock's own scope, systemd-cat for its journal tag.
      pkgs.systemd
      # flock, and setsid for the shell lock's own process group.
      pkgs.util-linux
    ];
    runtimeEnv = {
      SILERE_LOCK_SCREEN = cfg.lockScreen;
      # By absolute path: the lock runs with the shell's own PATH, which has
      # no qs on it.
      SILERE_LOCK_QS = lib.getExe' cfg.commands.quickshellPackage "qs";
      SILERE_LOCK_QML = "${cfg.commands.silereShellPackage}/share/silere-shell/lock.qml";
      SILERE_SHELL_PATH = cfg.commands.silereShellPath;
    };
    text = builtins.readFile ../scripts/silere-lock.sh;
  };

  # The shell menu's Lock entries (silere.nix's lockCommand). They run the
  # wrapper directly rather than asking hypridle through `loginctl
  # lock-session`: logind answers that request by emitting a signal, so its
  # success says nothing about whether a running, subscribed hypridle picked
  # it up, and a menu Lock that silently does nothing leaves the desktop open.
  # The wrapper's guard keeps this from ever making a second lock. A bare path,
  # no arguments: it runs the same whether the shell splits the command or
  # hands it to sh -c.
  lockRequestScript = pkgs.writeShellApplication {
    name = "silere-lock-request";
    runtimeInputs = [ lockScript ];
    text = ''
      exec silere-lock
    '';
  };
in
{
  options.local.hyprland = {
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

      lockScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "silere-lock, the wrapper every session lock goes through (hypridle's lock_cmd and the shell menu's Lock).";
      };

      lockRequestScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Lock request the shell menu runs: the silere-lock wrapper, directly.";
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

      silereShellPackage = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = ''
          Packaged silere-shell derivation (see silere.nix), exposed so other
          Hyprland module files can reach its bundled files -- e.g.
          wallpaper.nix's matugen template, which ships under this
          package's share/silere-shell/matugen/.
        '';
      };

      quickshellPackage = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "Quickshell package shared by the shell service and every IPC consumer.";
      };

      silereShellPath = lib.mkOption {
        type = lib.types.str;
        internal = true;
        description = ''
          The curated PATH the silere-shell service runs with (defined in
          silere.nix), exposed so the lock process the lock wrapper starts
          resolves the same tools as the bar: its font scan needs fc-list,
          and its probes should agree with the bar's.
        '';
      };

      wallpaperSetScript = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = ''
          Packaged wallpaper-set script (defined in wallpaper.nix, assigned
          here the same way silereShellPackage is above), exposed so
          silere.nix can point the shell's wallpaperCommand setting at this
          exact binary -- the picker, its Random button, the Super+Shift+W
          chord, and a terminal `wallpaper-set` invocation then all funnel
          through the one script, so awww's swap, the hyprlock stable-path
          convert, matugen's retint, and the glass sample can never be
          applied out of step with each other.
        '';
      };

      wallpapersDir = lib.mkOption {
        type = lib.types.str;
        internal = true;
        description = ''
          Absolute wallpaper directory (assigned in default.nix from the
          same expression that seeds $WALLPAPERS_DIR for the session),
          exposed here so silere.nix's wallpapersDir default and
          default.nix's session variable can never drift into two different
          computations of the same directory.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    local.hyprland.commands = {
      inherit
        caffeineScript
        lockRequestScript
        lockScript
        screenshotScript
        screenrecordScript
        ;
    };
  };
}
