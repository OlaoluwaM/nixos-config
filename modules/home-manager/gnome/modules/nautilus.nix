{ config, lib, ... }:

let
  cfg = config.local.gnome;
  xdgDirs = config.xdg.userDirs;
  documents = xdgDirs.documents;
  downloads = xdgDirs.download;
  music = xdgDirs.music;
  pictures = xdgDirs.pictures;
  videos = xdgDirs.videos;
  # Upper case because that is how Gnome has it and changing it isn't easy and we want it to be unified across desktop profiles, that is all screenshots and screencasts should be stored in the same place
  screenshots = "${pictures}/Screenshots";
  screencasts = "${videos}/Screencasts";
  wallpapers = "${pictures}/wallpapers";
  gtkBookmarks = ''
    file://${documents}/job-items
    file://${screencasts}
    file://${screenshots}
    file://${xdgDirs.desktop}
    file://${wallpapers}
    file://${documents}/library/non-technical-shelf
    file://${documents}/library/technical-shelf
    file://${documents}
    file://${music}
    file://${pictures}
    file://${videos}
    file://${downloads}
  '';
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "gtk-3.0/bookmarks".text = gtkBookmarks;
      "gtk-4.0/bookmarks".text = gtkBookmarks;
    };

    dconf.settings = {
      "org/gtk/gtk4/settings/file-chooser" = {
        show-hidden = true;
        sort-directories-first = false;
      };

      "org/gtk/settings/file-chooser" = {
        date-format = "regular";
        location-mode = "path-bar";
        show-hidden = true;
        show-size-column = true;
        show-type-column = true;
        sort-column = "name";
        sort-directories-first = false;
        sort-order = "ascending";
        type-format = "category";
      };

      "org/gnome/nautilus/icon-view" = {
        default-zoom-level = "small-plus";
      };

      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "icon-view";
        search-filter-time-type = "last_modified";
        show-hidden-files = true;
        show-delete-permanently = true;
      };
    };
  };
}
