{
  config,
  lib,
  ...
}:

let
  cfg = config.local.fsLayout;
  home = config.home.homeDirectory;
  data = config.xdg.dataHome;
  pictures = config.xdg.userDirs.pictures;
  applicationsDir = "${data}/applications";
  profileApplicationsDir = "${config.home.profileDirectory}/share/applications";

  dirs = [
    "${config.xdg.userDirs.desktop}/${cfg.devDirname}"
    "${config.xdg.userDirs.download}/isos"
    "${data}/icons"
    "${data}/themes"
    "${data}/fonts"
    "${config.xdg.userDirs.videos}/Screencasts"
    "${pictures}/Screenshots"
    "${pictures}/Wallpapers"
    "${home}/sys-bak"
  ];

in
{
  options.local.fsLayout = {
    devDirname = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      example = "dev";
      description = ''
        Name of the development directory created under the XDG desktop directory.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # "writeBoundary" represents the point where file system changes are allowed during the lifecycle of activating a generation
      home.activation.createPersonalDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p $VERBOSE_ARG ${lib.escapeShellArgs dirs}
      '';

      home.activation.createLegacyXdgLinks = lib.hm.dag.entryAfter [ "createPersonalDirs" ] ''
        [[ -e "$HOME/.icons" || -L "$HOME/.icons" ]] || run ln -sf $VERBOSE_ARG "${data}/icons" "$HOME/.icons"
        [[ -e "$HOME/.themes" || -L "$HOME/.themes" ]] || run ln -sf $VERBOSE_ARG "${data}/themes" "$HOME/.themes"
        [[ -e "$HOME/.fonts" || -L "$HOME/.fonts" ]] || run ln -sf $VERBOSE_ARG "${data}/fonts" "$HOME/.fonts"
      '';
    }

    (lib.mkIf config.local.gnome.enable {
      # GNOME does not reliably pick up new Home Manager desktop entries from
      # ~/.nix-profile/share/applications until the session is restarted. See:
      # https://discourse.nixos.org/t/apps-installed-via-home-manager-are-not-visible-within-gnome/48252
      #
      # The common workaround is to expose the profile's applications directory
      # under ~/.local/share/applications/nix. That makes GNOME rescan without a
      # login cycle, but it also changes desktop entry IDs from foo.desktop to
      # nix-foo.desktop, which causes duplicate search results whenever GNOME
      # also sees foo.desktop through XDG_DATA_DIRS.
      #
      # Instead, link each profile desktop file directly into the user's local
      # applications directory while preserving the original basename. This keeps
      # GNOME's file-monitor-friendly local path without changing desktop entry
      # IDs. It intentionally skips unmanaged files in the target directory so
      # locally-authored launchers are not overwritten.
      home.activation.linkProfileDesktopFiles = lib.hm.dag.entryAfter [
        "installPackages"
        "linkGeneration"
      ] ''
        applicationsDir=${lib.escapeShellArg applicationsDir}
        profileApplicationsDir=${lib.escapeShellArg profileApplicationsDir}

        # Ensure GNOME's user-local applications directory exists.
        run mkdir -p $VERBOSE_ARG "$applicationsDir"

        # Remove the older directory-symlink workaround if it exists. That
        # workaround made GNOME notice apps, but also changed desktop entry IDs
        # to nix-*.desktop and caused duplicate search results.
        if [[ -L "$applicationsDir/nix" ]]; then
          run rm $VERBOSE_ARG "$applicationsDir/nix"
        fi

        # Clean up stale symlinks created by this activation when the profile no
        # longer contains the desktop file they point at.
        for linkedDesktopFile in "$applicationsDir"/*.desktop; do
          [[ -L "$linkedDesktopFile" ]] || continue

          linkTarget="$(readlink "$linkedDesktopFile")"

          if [[ "$linkTarget" == "$profileApplicationsDir"/*.desktop && ! -e "$linkTarget" ]]; then
            run rm $VERBOSE_ARG "$linkedDesktopFile"
          fi
        done

        # Expose each profile desktop entry at the top level of the user-local
        # applications directory while preserving its original desktop file ID.
        for desktopFile in "$profileApplicationsDir"/*.desktop; do
          [[ -e "$desktopFile" ]] || continue

          target="$applicationsDir/$(basename "$desktopFile")"

          # Do not overwrite desktop entries managed by other tools or by hand.
          if [[ -e "$target" || -L "$target" ]]; then
            if [[ ! -L "$target" || "$(readlink "$target")" != "$profileApplicationsDir"/*.desktop ]]; then
              _i "Skipping unmanaged desktop entry $target"
              continue
            fi
          fi

          # Refresh the symlink so it follows the currently active generation.
          run ln -sfnT $VERBOSE_ARG "$desktopFile" "$target"
        done
      '';
    })
  ];
}
