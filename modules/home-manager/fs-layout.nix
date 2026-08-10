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
    # See ./gnome/default.nix on why these two need to be title cased
    "${config.xdg.userDirs.videos}/Screencasts"
    "${pictures}/Screenshots"
    "${pictures}/wallpapers"
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

    {
      # Desktop environments and app launchers should be able to find Home
      # Manager's launchers under ~/.nix-profile/share/applications, but not all
      # of them handle that profile path reliably during a running session. The
      # files can be valid, and tools like gtk-launch can still run them, while
      # the app search UI keeps using an old app list until logout/login. GNOME
      # exposed this with Kitty: kitty.desktop was present and valid, but GNOME
      # search only showed it after the file also appeared in the standard
      # user-local applications directory. See:
      # https://discourse.nixos.org/t/apps-installed-via-home-manager-are-not-visible-within-gnome/48252
      #
      # The short workaround is to link the whole Home Manager applications
      # directory as ~/.local/share/applications/nix. Launchers tend to notice
      # that local path quickly, but the extra "nix/" folder changes each app's
      # launcher ID: foo.desktop becomes nix-foo.desktop. If the launcher also
      # sees foo.desktop through XDG_DATA_DIRS, the same app can appear twice.
      #
      # So instead, link each launcher file directly into the user's local
      # applications directory. That uses the most common user-local launcher
      # path while keeping the original filename, so foo.desktop stays
      # foo.desktop.
      # Existing local launchers are skipped on purpose so hand-written entries
      # and app-created entries are not overwritten.
      home.activation.linkProfileDesktopFiles =
        lib.hm.dag.entryAfter
          [
            "installPackages"
            "linkGeneration"
          ]
          ''
            applicationsDir=${lib.escapeShellArg applicationsDir}
            profileApplicationsDir=${lib.escapeShellArg profileApplicationsDir}

            # Make sure the user-local launcher directory exists.
            run mkdir -p $VERBOSE_ARG "$applicationsDir"

            # Remove the older "applications/nix" shortcut if it is still around.
            # It helped launchers notice apps, but it also renamed launcher IDs to
            # nix-*.desktop and could create duplicate results.
            if [[ -L "$applicationsDir/nix" ]]; then
              run rm $VERBOSE_ARG "$applicationsDir/nix"
            fi

            # Remove links this activation created for apps that are no longer in
            # the current Home Manager profile.
            for linkedDesktopFile in "$applicationsDir"/*.desktop; do
              [[ -L "$linkedDesktopFile" ]] || continue

              linkTarget="$(readlink "$linkedDesktopFile")"

              if [[ "$linkTarget" == "$profileApplicationsDir"/*.desktop && ! -e "$linkTarget" ]]; then
                run rm $VERBOSE_ARG "$linkedDesktopFile"
              fi
            done

            # Put each Home Manager launcher directly in the local launcher
            # directory, keeping the same filename and therefore the same app ID.
            for desktopFile in "$profileApplicationsDir"/*.desktop; do
              [[ -e "$desktopFile" ]] || continue

              target="$applicationsDir/$(basename "$desktopFile")"

              # Leave local launchers alone unless they are links we created before.
              if [[ -e "$target" || -L "$target" ]]; then
                if [[ ! -L "$target" || "$(readlink "$target")" != "$profileApplicationsDir"/*.desktop ]]; then
                  _i "Skipping unmanaged desktop entry $target"
                  continue
                fi
              fi

              # Refresh the link so it follows the currently active generation.
              run ln -sfnT $VERBOSE_ARG "$desktopFile" "$target"
            done
          '';
    }
  ];
}
