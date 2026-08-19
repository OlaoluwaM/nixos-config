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
# wallpaper-set is exposed to the rest of the profile as
# local.hyprland.commands.wallpaperSetScript (option declared in
# commands.nix, assigned below -- the same re-plumb silere.nix uses for
# commands.silereShellPackage), so silere.nix can point the shell's
# wallpaperCommand setting at this exact script.
#
# The human entry points used to be a pair of Vicinae script commands. They
# are now the shell's own picker instead (Super+SHIFT+W and the "Wallpapers"
# desktop entry, both in keybindings.nix): Vicinae's script-command argument
# types only support a single static text field, never a live directory
# listing, so a real picker over $WALLPAPERS_DIR was never something Vicinae
# itself could render -- only the shell's own overlay can.
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
      # unstable deliberately: stable ships 4.0.0, whose config struct has no
      # `prefer` field (checked against the v4.0.0 source), so the config.toml
      # preference below is only real from 4.1.0 -- which unstable pins.
      unstable.matugen
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
      # --prefer rides the CLI even though config.toml carries the same
      # preference: config-level `prefer` only exists from matugen 4.1.0, and
      # this script's pinned matugen is whatever nixpkgs ships -- 4.0.0 today,
      # which reads the config fine and silently ignores the key. Trusting the
      # config alone is exactly how this fix broke once already. Mode and
      # scheme type have no config key at any version, so they are pinned here
      # too: this shell is dark-only by design, and the theme's role mapping
      # was built against tonal-spot's palette shape.
      matugen image "$src" --prefer saturation -m dark -t scheme-tonal-spot

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
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ wallpaperSetScript ];

    # Re-plumb, not a new definition: the derivation stays right here where
    # wallpaper-set's one Nix-level dependency (the stable wallpaper path)
    # lives, but the value is also visible under local.hyprland.commands so
    # silere.nix can reach it (see the comment on commands.wallpaperSetScript
    # in commands.nix, and this file's header comment above).
    local.hyprland.commands.wallpaperSetScript = wallpaperSetScript;

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

    # Replaces the fork installer's role here (scripts/install.sh normally
    # writes this file's [templates.silere-shell] table itself): Nix already
    # owns the checkout and packages the matugen template inside it, so it
    # owns wiring matugen to that template too. silere-shell's
    # MatugenPalette.qml live-watches output_path and repaints as soon as
    # matugen rewrites it -- no shell restart needed.
    # `prefer` is load-bearing, not taste: when matugen 4.x extracts several
    # candidate source colors it PROMPTS for a choice, and with no terminal
    # attached (the shell's picker, the Super+Shift+W chord -- every real
    # caller) it errors out instead, which under wallpaper-set's set -e also
    # skipped the stable-path convert -- the old "wallpaper resets on rebuild"
    # bug. The maintainer's endorsed scripted answer is a preference
    # (InioX/matugen#255). saturation = the most chromatic candidate, which is
    # what an accent derived from artwork should be, and the most-chosen value
    # in real dotfiles. NOTE: matugen only reads this key from 4.1.0; the
    # deployed 4.0.0 ignores it, so wallpaper-set passes --prefer on the CLI
    # as the actual carrier and this entry is forward-compatibility.
    xdg.configFile."matugen/config.toml".text = ''
      [config]
      version_check = false
      prefer = "saturation"

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
          # Without this, a oneshot reads inactive(dead) the moment it finishes,
          # and every home-manager activation sees a wanted-but-inactive unit
          # and runs it again -- re-pushing the stable path (and replaying the
          # awww transition) on every rebuild, not just at login. active(exited)
          # makes "once per session" mean what it says.
          RemainAfterExit = true;
          ExecStart = "${lib.getExe unstable.awww} img ${cfg.wallpaper}";
        };
      };
    };
  };
}
