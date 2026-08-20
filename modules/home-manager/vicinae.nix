{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.local.vicinae;
  fonts = config.local.fonts;
  iconTheme = config.gtk.iconTheme.name;
  extensionPkgs = inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system};
  goldfish = pkgs.callPackage ../../pkgs/goldfish { };
in
{
  options.local.vicinae = {
    enable = lib.mkEnableOption "vicinae configuration";

    systemd.target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = ''
        User systemd target that starts and stops the Vicinae service.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Vicinae follows the wallpaper-derived Matugen theme below instead of
    # Catppuccin's fixed palette.
    catppuccin.vicinae.enable = false;

    home.packages = [
      goldfish
      pkgs.file
    ];

    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
        target = cfg.systemd.target;
      };

      # useLayerShell
      settings = {
        font.normal = {
          family = fonts.ui.family;
          size = fonts.ui.size;
        };

        theme = {
          dark = {
            name = "matugen";
            icon_theme = iconTheme;
          };
          light.icon_theme = iconTheme;
        };

        launcher_window = {
          # Vicinae is a transient surface, so track the shell popup glass
          # opacity rather than the slightly more solid persistent bar.
          opacity = config.local.hyprland.silere.glassOpacity;
          # On Linux, Vicinae's blur material asks the compositor for
          # background blur. Hyprland's matching layer rule supplies the same
          # blur tuning used by the shell surfaces.
          material = "blur";
          layer_shell = {
            enabled = true;
            # We had an issue with satty where taking a screenshot of vicinae would hog keyboard input so trying to "ESC" or "ENTER" while both satty and vicinae were active would not work as expected. We'd need to close vicinae before satty could get keyboard input again. This option only passes keyboard input to vicinae when it is in focus. This way if we have satty up, it can correctly take input without interference from vicinae.
            keyboard_interactivity = "on_demand";
          };
        };

        providers = {
          # Configuring extensions: https://docs.vicinae.com/nixos#configuring-extensions
          "@Osmagtor/vicinae-extension-simple-dictionary-0" = {
            preferences = {
              default_language = "en";
            };
          };
        };
      };

      extensions = [
        # Extensions can be found here: https://github.com/vicinaehq/extensions/tree/main/extensions
        extensionPkgs.fuzzy-files
        extensionPkgs.hypr-keybinds
        extensionPkgs.nix
        extensionPkgs.player-pilot
        extensionPkgs.simple-bookmarks
        extensionPkgs.simple-dictionary
        extensionPkgs.supergenpass
        extensionPkgs.wifi-commander
      ];
    };
  };
}
