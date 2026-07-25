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
in
{
  options.local.dejaDup = {
    enable = lib.mkEnableOption "Deja Dup backups configuration";
  };

  config = lib.mkIf cfg.enable {
    # No duplicity/borg/restic needed alongside: the nixpkgs package bakes in
    # absolute paths to its backend tools at build time.
    home.packages = [ pkgs.deja-dup ];

    # Deja Dup keeps its whole configuration in GSettings, so it's declared
    # here as dconf keys. Migrated from the Fedora flatpak's keyfile
    # (~/.var/app/org.gnome.DejaDup/config/glib-2.0/settings/keyfile).
    #
    # Only "intent" keys are declared. Runtime state (last-run, last-backup,
    # periodic-timestamp, window geometry) is deliberately left out — dconf
    # keys are rewritten on every HM activation, so declaring state would keep
    # resetting the scheduler's bookkeeping.
    #
    # Not declarable at all: the Google OAuth token and encryption passphrase
    # live in the keyring (libsecret), so the first backup on a fresh install
    # still needs an interactive Google sign-in in the app.
    dconf.settings = {
      "org/gnome/deja-dup" = {
        backend = "google";

        # Automatic weekly backups, old snapshots pruned after ~3 months.
        periodic = true;
        "periodic-period" = 7;
        "delete-after" = 90;

        # Carried over verbatim from the Fedora install. Some entries are
        # Fedora-era (rpms, flatpak data under ~/.var) and are pruned by hand,
        # not by this module.
        # XDG variables where one exists; plain ${home} only for dirs outside
        # the XDG layout (sys-bak, flatpak's ~/.var, agent CLIs' dotdirs).
        "include-list" = [
          "${userDirs.download}/rpms"
          "${userDirs.pictures}/memorables"
          "${userDirs.pictures}/useful-images"
          "${dataHome}/fonts"
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
          "${userDirs.pictures}/wallpapers"
          "${userDirs.desktop}/${config.local.fsLayout.devDirname}/archive"
        ];
        "exclude-list" = [
          "$TRASH"
          "$DOWNLOAD"
        ];
      };

      # Folder inside Google Drive that receives the backup chain. Renamed from
      # the Fedora-era "fedora-backups"; a new folder starts a fresh chain, and
      # the old one stays restorable by pointing the app back at it.
      "org/gnome/deja-dup/google".folder = "linux-system-backups-deja-dup";
    };

    # Scheduled backups are driven by deja-dup-monitor, which the package ships
    # as an XDG autostart entry. Link it into ~/.config/autostart explicitly so
    # scheduling works even when the profile's etc/xdg isn't on
    # XDG_CONFIG_DIRS; user entries take precedence over system ones, so this
    # never duplicates.
    xdg.configFile."autostart/org.gnome.DejaDup.Monitor.desktop".source =
      "${pkgs.deja-dup}/etc/xdg/autostart/org.gnome.DejaDup.Monitor.desktop";
  };
}
