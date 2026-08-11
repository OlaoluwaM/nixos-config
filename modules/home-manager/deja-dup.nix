{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.dejaDup;
  home = config.home.homeDirectory;
  inherit (config.xdg) configHome dataHome userDirs;

  dejaDupAppId = "org.gnome.DejaDup";
  flatpak = "${pkgs.flatpak}/bin/flatpak";

  includeList = [
    "${userDirs.download}/rpms"
    "${userDirs.pictures}"
    "${dataHome}/fonts"
    "${dataHome}/zoxide" # _ZO_DATA_DIR (see dotfiles.nix)
    "${home}/sys-bak"
    "${userDirs.videos}/useful-stuff"
    userDirs.documents
    "${userDirs.download}/image-merge-staging-area"
    "${userDirs.videos}/random-vids"
    "${userDirs.videos}/YouTube"
    "${userDirs.music}/local-music"
    "${userDirs.music}/lies-o-p-full-soundtrack-original"
    "${userDirs.music}/lies-o-p-full-soundtrack-partitioned"
    "${home}/.var/app/io.github.flattool.Warehouse/data/Snapshots"
    "${home}/.var"
    "${userDirs.desktop}/digital-brain"
    "${home}/.claude"
    "${home}/.codex"
    configHome
    "${userDirs.desktop}/${config.local.fsLayout.devDirname}/archive"
  ];

  excludeList = [
    "$TRASH"
    "$DOWNLOAD"
  ];

  # JSON string/list syntax is also valid GVariant syntax for these values.
  gvariant = value: lib.escapeShellArg (builtins.toJSON value);

in
{
  options.local.dejaDup = {
    enable = lib.mkEnableOption "Deja Dup backups configuration";
  };

  config = lib.mkIf cfg.enable {
    #
    # Install the working Flatpak instead of nixpkgs' deja-dup.
    #
    services.flatpak.packages = [
      dejaDupAppId
    ];

    #
    # Configure the Flatpak's own GSettings store.
    #
    # With the deja-dup flatpak, we cannot directly manage durable config using dconf because the flatpak version isn't configured with dconf
    #
    # We also cannot use home.file on the flatpak's configuration files because they are mutable and change as the app is used. We do not want to mess with that either.
    # Instead, we hook into the nix-flatpak activation mechanism to configure the deja-dup flatpak with the necessary values at activation time.
    #
    # Runtime state such as last-run, last-backup and periodic-timestamp still remains owned by Deja Dup itself.
    #
    # Google OAuth credentials and the backup encryption password also
    # remain in the secrets/keyring system and are configured interactively.
    #
    # We are using the flatpak over the native nixpkgs version because the native application doesn't seem to connect to google drive properly.
    home.activation.configureDejaDup = lib.hm.dag.entryAfter [ "flatpak-managed-install" ] ''
      if ${flatpak} info --user ${dejaDupAppId} >/dev/null 2>&1; then
        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup backend ${gvariant "google"}

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup periodic true

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup periodic-period 7

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup delete-after 90

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup include-list ${gvariant includeList}

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup exclude-list ${gvariant excludeList}

        run ${flatpak} run --user --command=gsettings ${dejaDupAppId} \
          set org.gnome.DejaDup.Google folder \
          ${gvariant "linux-system-backups-deja-dup"}
      else
        _i "Deja Dup Flatpak is not installed; skipping configuration"
      fi
    '';
  };
}
