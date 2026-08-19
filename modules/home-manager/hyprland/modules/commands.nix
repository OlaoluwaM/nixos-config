{
  config,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# This module packages the shared helper scripts other Hyprland modules
# launch (screenshot, screenrecord, manual caffeine/idle-inhibit toggle) and
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
      # hyprctl + jq: the window mode derives its capture geometry from the
      # active window the same way screenshotScript's window mode does.
      hyprland
      jq
      libnotify
      procps
      slurp
      wf-recorder
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
      pkgs.quickshell
    ];
    # `qs ipc` locates the running instance by config path, and the shell
    # runs from a store path via -p, not the default config dir -- a bare
    # `qs ipc call` finds nothing and the script silently fell back to raw
    # unit control (losing the preset). The script reads this variable to
    # target the exact packaged shell.qml the service runs.
    runtimeEnv.SILERE_SHELL_QML = "${cfg.commands.silereShellPackage}/share/silere-shell/shell.qml";
    text = builtins.readFile ../scripts/hypr-shell-caffeine.sh;
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
          Hyprland module files can reach its bundled assets -- e.g.
          wallpaper.nix's matugen template, which ships under this
          package's share/silere-shell/assets/.
        '';
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
  };
}
