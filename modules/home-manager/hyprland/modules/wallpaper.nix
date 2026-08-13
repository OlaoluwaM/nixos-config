{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This module is the wallpaper pipeline for the Hyprland profile: one script
# (wallpaper-set) that fans a chosen image out to everything that needs to
# know about it --
#   - awww: the live desktop background daemon
#   - matugen: retints silere-shell (and anything else matugen drives) from
#     the new image's palette
#   - local.hyprland.wallpaper: the stable path hyprlock reads, kept in sync
#     by converting (not copying) into it
#
# -- plus the two entry points that call wallpaper-set for a human: a pair of
# Vicinae script commands, and the Super+SHIFT+W keybind (keybindings.nix)
# that opens the random one.
let
  cfg = config.local.hyprland;

  # Same placeholder default.nix used to provision the stable wallpaper path
  # directly; wallpaper.nix now owns seeding it instead (see the activation
  # script below).
  placeholderWallpaper = pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath;

  # The single entry point the rest of this pipeline funnels through. Only
  # this script needs a Nix-level value (the stable wallpaper path), so it
  # stays inline here instead of living under ../scripts/ with the other
  # helper scripts, which are pure bash parameterized by args/env only.
  wallpaperSetScript = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [
      unstable.awww
      pkgs.matugen
      pkgs.imagemagick
      pkgs.coreutils
    ];
    text = ''
      # shellcheck shell=bash

      # Beginner orientation:
      #
      # Usage: wallpaper-set <image-path>
      #
      # Updates, in order: the live desktop background (awww), the shell's
      # matugen-derived theme, and the stable path hyprlock reads.

      if [ "$#" -ne 1 ]; then
          echo "usage: wallpaper-set <image-path>" >&2
          exit 1
      fi

      src="$1"

      if [ ! -f "$src" ] || [ ! -r "$src" ]; then
          echo "wallpaper-set: not a readable file: $src" >&2
          exit 1
      fi

      awww img "$src"
      matugen image "$src"

      stable="${cfg.wallpaper}"
      stable_dir="$(dirname -- "$stable")"

      # Convert into a temp file in the same directory as the stable path,
      # then rename over it. Rename is atomic on the same filesystem, so
      # hyprlock (or anything else reading that path) never observes a
      # partially written file. Converting rather than copying also means
      # the stable path's .png extension always matches the real pixel
      # format, no matter what format the picked image was in.
      tmp="$(mktemp "$stable_dir/.wallpaper-set.XXXXXX.png")"
      trap 'rm -f "$tmp"' EXIT
      magick "$src" "$tmp"
      mv -f "$tmp" "$stable"
      trap - EXIT
    '';
  };

  # Zero-input: picks a random image from $WALLPAPERS_DIR. This is what
  # Super+SHIFT+W opens (see keybindings.nix).
  vicinaeRandomWallpaperScript = pkgs.writeShellApplication {
    name = "random-wallpaper";
    runtimeInputs = [
      wallpaperSetScript
      pkgs.coreutils
      pkgs.findutils
    ];
    text = builtins.readFile ../scripts/vicinae-random-wallpaper.sh;
  };

  # Takes one argument: a filename inside $WALLPAPERS_DIR, or an absolute
  # path. Vicinae's script-command dropdown argument only supports a single
  # static option (not a live directory listing), so a picker over
  # $WALLPAPERS_DIR isn't something Vicinae can render declaratively --  a
  # text argument is the cleanest mechanism it actually supports for this.
  vicinaeSetWallpaperScript = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = [
      wallpaperSetScript
      pkgs.coreutils
    ];
    text = builtins.readFile ../scripts/vicinae-set-wallpaper.sh;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ wallpaperSetScript ];

    # The stable wallpaper path must be a real, user-writable file --
    # wallpaper-set overwrites it in place on every change, which a
    # read-only Nix store symlink (the old xdg.configFile approach) cannot
    # support. Home Manager only seeds it once: an existing file (this
    # profile's own prior choice, or a hand-picked one) is never clobbered.
    home.activation.silereWallpaperSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ ! -e "${cfg.wallpaper}" ]]; then
        run mkdir -p $VERBOSE_ARG "$(dirname -- "${cfg.wallpaper}")"
        run cp $VERBOSE_ARG "${placeholderWallpaper}" "${cfg.wallpaper}"
        run chmod $VERBOSE_ARG u+w "${cfg.wallpaper}"
      fi
    '';

    # Vicinae scans ~/.local/share/vicinae/scripts (XDG_DATA_HOME) for
    # script commands by default, so a plain xdg.dataFile placement is all
    # either command needs -- no Vicinae settings/preferences plumbing
    # required. The installed filename doubles as the command's stable id
    # (see keybindings.nix's Super+SHIFT+W deeplink).
    xdg.dataFile = {
      "vicinae/scripts/random-wallpaper".source = "${vicinaeRandomWallpaperScript}/bin/random-wallpaper";
      "vicinae/scripts/set-wallpaper".source = "${vicinaeSetWallpaperScript}/bin/set-wallpaper";
    };

    # Replaces the fork installer's role here (scripts/install.sh normally
    # writes this file's [templates.silere-shell] table itself): Nix already
    # owns the checkout and packages the matugen template inside it, so it
    # owns wiring matugen to that template too. silere-shell's
    # MatugenPalette.qml live-watches output_path and repaints as soon as
    # matugen rewrites it -- no shell restart needed.
    xdg.configFile."matugen/config.toml".text = ''
      [config]
      version_check = false

      [templates.silere-shell]
      input_path = "${cfg.commands.silereShellPackage}/share/silere-shell/assets/matugen-theme.json"
      output_path = "${config.xdg.configHome}/matugen/silere-shell.json"
    '';

    systemd.user.services = {
      hypr-shell-awww = {
        Unit = {
          Description = "awww wallpaper daemon";
          # Same reasoning as silere-shell.service's ordering: without it,
          # systemd could start awww-daemon before Hyprland (and a Wayland
          # display to connect to) is up, burning the unit's restart budget
          # on early, unrecoverable failures.
          After = [ config.wayland.systemd.target ];
          PartOf = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          ExecStart = lib.getExe' unstable.awww "awww-daemon";
          Restart = "on-failure";
        };
      };

      # awww-daemon starts with no wallpaper of its own; without this, a
      # fresh login shows a blank background until something calls
      # wallpaper-set again. Pushing the stable path (kept in sync with
      # whatever wallpaper-set last picked) makes the last wallpaper survive
      # login.
      hypr-shell-wallpaper-restore = {
        Unit = {
          Description = "Restore the last wallpaper into awww";
          After = [ "hypr-shell-awww.service" ];
          PartOf = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe unstable.awww} img ${cfg.wallpaper}";
        };
      };
    };
  };
}
