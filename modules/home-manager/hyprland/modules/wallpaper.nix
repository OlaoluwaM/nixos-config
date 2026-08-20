{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.hyprland;

  # Same placeholder default.nix used to provision the stable wallpaper path
  # directly; wallpaper.nix now owns seeding it instead (see the activation
  # script below).
  placeholderWallpaper = pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath;

  matugenConfig = (pkgs.formats.toml { }).generate "matugen-config.toml" {
    config = {
      # Matugen would still rebuild the SchemeContent palette for this
      # template, so caching would add files without making this faster.
      caching = false;
      version_check = false;
    };

    templates."silere-shell" = {
      input_path = "${cfg.commands.silereShellPackage}/share/silere-shell/assets/matugen-theme.json";
      output_path = "${config.xdg.configHome}/matugen/silere-shell.json";
      mode = "Dark";
      type = "SchemeContent";
    };
  };

  wallpaperSetScript = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [
      unstable.awww
      # Keep the packaged helper on the same Matugen version that the Hyprland
      # profile exposes for direct terminal use.
      unstable.matugen
      pkgs.imagemagick
      pkgs.coreutils
    ];
    runtimeEnv.HYPR_WALLPAPER_PATH = cfg.wallpaper;
    text = builtins.readFile ../scripts/wallpaper-set.sh;
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
    # writes this file's [templates.silere-shell] table itself). Home Manager
    # links the generated TOML into Matugen's standard config location.
    # silere-shell's MatugenPalette.qml watches output_path and repaints when
    # Matugen rewrites it, so no shell restart is needed.
    xdg.configFile."matugen/config.toml".source = matugenConfig;

    systemd.user.services = {
      hypr-shell-awww = {
        Unit = {
          Description = "awww wallpaper daemon";
          PartOf = [ config.wayland.systemd.target ];
        };

        Install.WantedBy = [ config.wayland.systemd.target ];

        Service = {
          # awww sends READY=1 after it creates its IPC socket. Let systemd
          # hold dependent units until the daemon can accept their commands.
          Type = "notify";
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
          Requires = [ "hypr-shell-awww.service" ];
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
          ExecStart = "${lib.getExe unstable.awww} img --transition-type grow ${cfg.wallpaper}";
        };
      };
    };
  };
}
