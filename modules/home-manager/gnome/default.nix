{
  config,
  lib,
  pkgs,
  hostConfig,
  unstable,
  ...
}:

let
  cfg = config.local.gnome;
  xdgDirs = config.xdg.userDirs;
  documents = xdgDirs.documents;
  downloads = xdgDirs.download;
  music = xdgDirs.music;
  pictures = xdgDirs.pictures;
  videos = xdgDirs.videos;
  screenshots = "${pictures}/Screenshots";
  screencasts = "${videos}/Screencasts";
  wallpapers = "${pictures}/Wallpapers";
  enableAsusRogKeybindings = hostConfig.enableAsusRogKeybindings or false;
  # dconf stores GNOME settings as typed GVariant values; these helpers
  # preserve exact types for values Nix cannot infer, like tuples and variants.
  gvariant = lib.hm.gvariant;
  inherit (gvariant) mkTuple mkVariant;
  uint32 = gvariant.mkUint32;
  emptyStringArray = gvariant.mkEmptyArray gvariant.type.string;
  minneapolisWeatherLocation = mkVariant (mkTuple [
    (uint32 2)
    (mkVariant (mkTuple [
      "Minneapolis"
      "KMSP"
      true
      [
        (mkTuple [
          0.783357105556996
          (-1.6271510710263237)
        ])
      ]
      [
        (mkTuple [
          0.78504848668181115
          (-1.627761011240018)
        ])
      ]
    ]))
  ]);
  sanFranciscoWorldClock = mkVariant (mkTuple [
    (uint32 2)
    (mkVariant (mkTuple [
      "San Francisco"
      "KOAK"
      false
      [
        (mkTuple [
          0.65832848982162007
          (-2.133408063190589)
        ])
      ]
      [
        (mkTuple [
          0.65832848982162007
          (-2.133408063190589)
        ])
      ]
    ]))
  ]);
  customKeybindingSchema = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
  # Used in the media-keys custom-keybindings list, which expects slash-wrapped dconf paths.
  mkCustomKeybindingPath = index: "/${customKeybindingSchema}/custom${toString index}/";
  # Used as a dconf.settings attr key, where Home Manager expects the same path without edge slashes.
  mkCustomKeybindingKey = index: "${customKeybindingSchema}/custom${toString index}";
  customKeybindings =
    map mkCustomKeybindingPath (lib.range 0 5)
    ++ lib.optionals enableAsusRogKeybindings [
      (mkCustomKeybindingPath 6)
      (mkCustomKeybindingPath 7)
    ];
  favoriteApps = [
    "firefox.desktop"
    "kitty.desktop"
  ]
  ++ lib.optionals enableAsusRogKeybindings [
    "rog-control-center.desktop"
  ];
  gtkBookmarks = ''
    file://${documents}/job-items
    file://${screencasts}
    file://${screenshots}
    file://${xdgDirs.desktop}
    file://${wallpapers}/images wallpapers
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
  options.local.gnome = {
    enable = lib.mkEnableOption "Gnome configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Stable packages
      dconf-editor

      gnome-tweaks
      gnome-extension-manager
      gnome-keyring
      gnome-sound-recorder

      kooha

      libappindicator-gtk3
      libgda5

      pinentry-gnome3

      seahorse
      sticky-notes

      # Unstable Packages
      unstable.gthumb
      unstable.gtk3

      unstable.mission-center

      unstable.refine
    ];

    services.flatpak.packages = [
      "org.gnome.Chess"
      "com.leinardi.gst"
    ];

    xdg.configFile = {
      "gtk-3.0/bookmarks".text = gtkBookmarks;
      "gtk-4.0/bookmarks".text = gtkBookmarks;
    };

    programs.gnome-shell = {
      enable = true;

      extensions = [
        { package = unstable.gnomeExtensions.appindicator; }
        { package = unstable.gnomeExtensions.blur-my-shell; }
        { package = unstable.gnomeExtensions.caffeine; }
        { package = unstable.gnomeExtensions.clipboard-indicator; }
        { package = unstable.gnomeExtensions.gsconnect; }
        { package = unstable.gnomeExtensions.just-perfection; }
        { package = unstable.gnomeExtensions.mpris-label; }
        { package = unstable.gnomeExtensions.vitals; }
        { package = pkgs.gnomeExtensions.space-bar; }
      ];
    };

    dconf.settings = {
      # Appearance

      # TODO: Enable once you've install NixOS proper and update the uris
      # "org/gnome/desktop/background" = {
      #   picture-options = "zoom";
      #   picture-uri = "file:///home/olaolu/.config/background";
      #   picture-uri-dark = "file:///home/olaolu/.config/background";
      # };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        # cursor-theme = "catppuccin-mocha-dark-cursors"; TODO: Enable once the catppuccin-mocha-dark-cursors cursor pack is install (alongside icons)
        # TODO: Uncomment these once fonts have been restored on system
        # document-font-name = "SF Pro Display Medium 10";
        enable-animations = true;
        enable-hot-corners = false;
        font-antialiasing = "rgba";
        font-hinting = "medium";
        # font-name = "SF Pro Display Medium 10";
        gtk-theme = "Adwaita-dark";
        # icon-theme = "Colloid-Dark"; TODO: Enable once the colliod dark icon theme has been installed
        monospace-font-name = "Berkeley Mono Medium 10";
        toolkit-accessibility = false;
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        click-method = "fingers";
        two-finger-scrolling-enabled = true;
      };

      # Notifications and privacy
      "org/gnome/desktop/notifications" = {
        show-banners = false;
      };

      "org/gnome/desktop/privacy" = {
        report-technical-problems = true;
      };

      "org/gnome/desktop/datetime" = {
        automatic-timezone = false;
      };

      # Windows and workspaces
      "org/gnome/desktop/wm/preferences" = {
        action-double-click-titlebar = "toggle-maximize";
        action-middle-click-titlebar = "none";
        action-right-click-titlebar = "menu";
        button-layout = "close,minimize,maximize:appmenu";
        focus-mode = "click";
        resize-with-right-button = true;
        workspace-names = [
          "Study"
          "Dev"
          "Content"
          "Job Search"
        ];
      };

      "org/gnome/mutter" = {
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
        ];
      };

      "org/gnome/shell" = {
        disabled-extensions = [ "background-logo@fedorahosted.org" ];
        favorite-apps = favoriteApps;
      };

      "org/gnome/shell/weather" = {
        automatic-location = true;
        locations = [ minneapolisWeatherLocation ];
      };

      "org/gnome/shell/world-clocks" = {
        locations = [ sanFranciscoWorldClock ];
      };

      "org/gnome/system/location" = {
        enabled = true;
      };

      # Files
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
      };

      # Night light
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = false;
        night-light-schedule-from = 19.0;
        night-light-schedule-to = 8.0;
        night-light-temperature = uint32 2467;
      };

      # Extension settings
      "org/gnome/tweaks" = {
        show-extensions-notice = false;
      };

      "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
        brightness = 0.6;
        sigma = 30;
      };

      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = true;
        brightness = 0.6;
        sigma = 30;
        static-blur = true;
        style-dash-to-dock = 0;
      };

      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        brightness = 0.6;
        sigma = 30;
      };

      "org/gnome/shell/extensions/blur-my-shell/window-list" = {
        brightness = 0.6;
        sigma = 30;
      };

      "org/gnome/shell/extensions/caffeine" = {
        cli-toggle = false;
        countdown-timer = 1800;
        enable-mpris = true;
        indicator-position-max = 2;
        toggle-shortcut = [ "<Super>c" ];
        use-custom-duration = false;
        user-enabled = false;
      };

      "org/gnome/shell/extensions/clipboard-indicator" = {
        cache-size = 100;
        enable-keybindings = true;
        history-size = 50;
        move-item-first = true;
        strip-text = true;
        toggle-menu = [ "<Alt>v" ];
      };

      "org/gnome/shell/extensions/gsconnect" = {
        enabled = true;
        missing-openssl = false;
      };

      "org/gnome/shell/extensions/just-perfection" = {
        accessibility-menu = true;
        dash-icon-size = 0;
        max-displayed-search-results = 0;
        panel = true;
        panel-in-overview = true;
        ripple-box = true;
        search = true;
        show-apps-button = true;
        startup-status = 1;
        support-notifier-showed-version = 34;
        support-notifier-type = 0;
        theme = false;
        window-demands-attention-focus = false;
        window-picker-icon = true;
        workspace = true;
        workspaces-in-app-grid = true;
      };

      "org/gnome/shell/extensions/mpris-label" = {
        auto-switch-to-most-recent = true;
        extension-place = "left";
        left-click-action = "play-pause";
        left-padding = 0;
        middle-click-action = "activate-player";
        right-click-action = "open-menu";
        right-padding = 25;
        second-field = "";
        use-album = false;
      };

      "org/gnome/shell/extensions/space-bar/appearance" = {
        application-styles = ''
          .space-bar {
            -natural-hpadding: 12px;
          }

          .space-bar-workspace-label.active {
            margin: 0 4px;
            background-color: rgba(255,255,255,0.3);
            color: rgba(255,255,255,1);
            border-color: rgba(0,0,0,0);
            font-weight: 700;
            border-radius: 4px;
            border-width: 0px;
            padding: 3px 8px;
          }

          .space-bar-workspace-label.inactive {
            margin: 0 4px;
            background-color: rgba(0,0,0,0);
            color: rgb(159,161,156);
            border-color: rgba(0,0,0,0);
            font-weight: 700;
            border-radius: 4px;
            border-width: 0px;
            padding: 3px 8px;
          }

          .space-bar-workspace-label.inactive.empty {
            margin: 0 4px;
            background-color: rgba(0,0,0,0);
            color: rgba(255,255,255,0.5);
            border-color: rgba(0,0,0,0);
            font-weight: 700;
            border-radius: 4px;
            border-width: 0px;
            padding: 3px 8px;
          }
        '';
        inactive-workspace-text-color = "rgb(159,161,156)";
      };

      "org/gnome/shell/extensions/space-bar/shortcuts" = {
        activate-empty-key = [ "<Alt><Super>n" ];
        enable-move-to-workspace-shortcuts = false;
        open-menu = [ "<Alt><Super>w" ];
      };

      "org/gnome/shell/extensions/vitals" = {
        hot-sensors = [
          "_memory_usage_"
          "_processor_usage_"
          "__temperature_avg__"
        ];
        position-in-panel = 0;
      };

      # Keybindings
      "org/gnome/shell/keybindings" = {
        focus-active-notification = emptyStringArray;
        screenshot = [ "<Control>F6" ];
        screenshot-window = [ "<Shift><Control>F6" ];
        show-screen-recording-ui = [ "<Shift>F6" ];
        show-screenshot-ui = [ "F6" ];
        toggle-message-tray = [ "<Super>v" ];
        toggle-quick-settings = [ "<Super>q" ];
      };

      "org/gnome/desktop/wm/keybindings" = {
        maximize = [ "<Super>Up" ];
        maximize-horizontally = emptyStringArray;
        maximize-vertically = [ "<Alt>Up" ];
        move-to-monitor-down = [ "<Alt><Super>Down" ];
        move-to-monitor-left = emptyStringArray;
        move-to-monitor-right = emptyStringArray;
        move-to-workspace-last = [ "<Shift><Alt>Right" ];
        move-to-workspace-left = [ "<Shift><Super>Left" ];
        move-to-workspace-right = [ "<Shift><Super>Right" ];
        toggle-fullscreen = [ "<Super>g" ];
        toggle-maximized = [ "<Super>f" ];
        unmaximize = [
          "<Super>Down"
          "<Alt>F5"
        ];
      };

      # Media keys
      "org/gnome/settings-daemon/plugins/media-keys" = {
        control-center = [ "<Super>u" ];
        custom-keybindings = customKeybindings;
        email = [ "<Super>m" ];
        home = [ "<Super>n" ];
        next = [ "<Alt>bracketright" ];
        pause = emptyStringArray;
        play = [ "F4" ];
        previous = [ "<Alt>bracketleft" ];
        www = [ "<Super>w" ];
      };

      # Custom keybindings
      "${mkCustomKeybindingKey 0}" = {
        binding = "<Super>o";
        command = "flatpak run md.obsidian.Obsidian";
        name = "Obsidian";
      };

      "${mkCustomKeybindingKey 1}" = {
        binding = "<Super>t";
        command = "kitty";
        name = "Terminal";
      };

      "${mkCustomKeybindingKey 2}" = {
        binding = "<Control><Alt>t";
        command = "ticktick";
        name = "TickTick";
      };

      "${mkCustomKeybindingKey 3}" = {
        binding = "<Super>s";
        command = "slack";
        name = "Slack";
      };

      "${mkCustomKeybindingKey 4}" = {
        binding = "<Alt>s";
        command = "flatpak run com.spotify.Client";
        name = "Spotify";
      };

      "${mkCustomKeybindingKey 5}" = {
        binding = "<Super>d";
        command = "flatpak run com.discordapp.Discord";
        name = "Discord";
      };

      "${mkCustomKeybindingKey 6}" = lib.mkIf enableAsusRogKeybindings {
        binding = "Launch1";
        command = "rog-control-center";
        name = "Rog Control Center";
      };

      "${mkCustomKeybindingKey 7}" = lib.mkIf enableAsusRogKeybindings {
        binding = "F5";
        command = "asusctl profile -n";
        name = "Switch Power profile";
      };
    };
  };
}
