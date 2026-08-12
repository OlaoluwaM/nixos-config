{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.gnome;
in
{
  config = lib.mkIf cfg.enable {
    # GSConnect handles sms:/tel: links. Declared next to the extension that
    # provides the desktop file (merged into the xdg.mimeApps set that
    # desktop.nix enables); kept as associations rather than defaults,
    # mirroring the Fedora setup. GSConnect cannot add them itself at runtime
    # because Home Manager owns mimeapps.list.
    xdg.mimeApps.associations.added = {
      "x-scheme-handler/sms" = "org.gnome.Shell.Extensions.GSConnect.desktop";
      "x-scheme-handler/tel" = "org.gnome.Shell.Extensions.GSConnect.desktop";
    };

    # Extensions must match the running GNOME Shell version, which comes from
    # stable nixpkgs. Source them all from stable `pkgs` so the GNOME version
    # stays aligned by construction; pulling them from `unstable` works only
    # while both channels happen to share a GNOME release.
    programs.gnome-shell.extensions = [
      { package = pkgs.gnomeExtensions.appindicator; }
      { package = pkgs.gnomeExtensions.blur-my-shell; }
      { package = pkgs.gnomeExtensions.caffeine; }
      { package = pkgs.gnomeExtensions.clipboard-indicator; }
      { package = pkgs.gnomeExtensions.gsconnect; }
      { package = pkgs.gnomeExtensions.just-perfection; }
      { package = unstable.gnomeExtensions.media-controller; }
      { package = pkgs.gnomeExtensions.vitals; }
    ];

    dconf.settings = {
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
        cache-size = 150;
        enable-keybindings = true;
        history-size = 80;
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

      "org/gnome/shell/extensions/vitals" = {
        hot-sensors = [
          "_memory_usage_"
          "_processor_usage_"
          "__temperature_avg__"
        ];
        position-in-panel = 0;
      };

      "org/gnome/shell/extensions/media-controller" = {
        # Keep it on the left like your old Mpris Label.
        panel-position = "left";

        # Panel contents.
        show-player-icon = true;
        show-title = true;
        show-artist = false;

        # Keep the panel reasonably compact.
        panel-text-width = 100;
        scroll-loop = true;

        # Visible panel controls.
        show-previous = true;
        show-play-pause = true;
        show-next = true;
        show-seek-backward = false;
        show-seek-forward = false;
        show-shuffle = false;
        show-loop = false;

        controls-on-left = false;
        hide-when-inactive = true;

        # Popup card.
        card-show-art = true;
        card-art-size = "medium";
        card-show-player-switcher = true;
        card-show-seek-bar = true;
        card-show-seek-buttons = true;
        card-show-shuffle = true;
        card-show-loop = true;

        seek-step-seconds = 10;
        card-width = 400;

        # Prevent two MPRIS players playing simultaneously.
        pause-others-on-play = true;
      };
    };
  };
}
