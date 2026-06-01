{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.desktop;
  fonts = config.local.fonts;

  fontSpec = font: "${font.name} ${toString font.size}";

  cursorTheme = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
  };

  iconTheme = {
    name = "Colloid-Dark";
    package = pkgs.colloid-icon-theme;
  };
in
{
  imports = [
    ./theme.nix
    ./gnome
    ./hyprland
  ];
  # This option should mirror what's in ../../modules/nixos/desktop.nix
  options.local.desktop = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "none"
      ];
      default = "gnome";
      example = "hyprland";
      description = ''
        Home Manager desktop profile to enable for this user.

        Use "gnome" for GNOME user packages and settings, "hyprland" for
        Hyprland user packages and settings, and "none" for users without a
        local graphical session.
      '';
    };
  };

  config = lib.mkMerge [
    {
      local.gnome.enable = cfg.profile == "gnome";
      local.hyprland.enable = cfg.profile == "hyprland";
    }

    (lib.mkIf (cfg.profile != "none") {
      # Shared app theming for graphical desktop sessions.
      gtk = {
        enable = true;
        colorScheme = "dark";
        cursorTheme = cursorTheme;
        iconTheme = iconTheme;
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
        font = {
          name = fonts.ui.name;
          size = fonts.ui.size;
        };
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
      };

      dconf.settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-size = cursorTheme.size;
        cursor-theme = cursorTheme.name;
        document-font-name = fontSpec fonts.document;
        font-name = fontSpec fonts.ui;
        gtk-theme = "Adwaita-dark";
        icon-theme = iconTheme.name;
        monospace-font-name = fontSpec fonts.mono;
      };

      home.pointerCursor = cursorTheme // {
        gtk.enable = true;
        x11.enable = true;
      };

      home.sessionVariables = {
        HYPRCURSOR_SIZE = toString cursorTheme.size;
        HYPRCURSOR_THEME = cursorTheme.name;
        XCURSOR_SIZE = toString cursorTheme.size;
        XCURSOR_THEME = cursorTheme.name;
      };

      qt = {
        enable = true;
        platformTheme.name = "adwaita";
        style.name = "adwaita-dark";
        qt5ctSettings.Fonts = {
          fixed = "\"${fonts.mono.family},${toString fonts.mono.size}\"";
          general = "\"${fonts.ui.family},${toString fonts.ui.size}\"";
        };
        qt6ctSettings.Fonts = {
          fixed = "\"${fonts.mono.family},${toString fonts.mono.size}\"";
          general = "\"${fonts.ui.family},${toString fonts.ui.size}\"";
        };
      };
    })
  ];
}
