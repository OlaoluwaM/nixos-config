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
    home.packages = with pkgs; [
      # Stable packages
      dconf-editor

      gnome-tweaks
      gnome-extension-manager
      gnome-keyring
      gnome-sound-recorder

      libappindicator-gtk3
      libgda5

      # Stable to match the hyprland module, so both profiles run the same
      # version of the same app.
      mission-center

      seahorse
      sticky-notes

      # Unstable Packages
      unstable.gthumb
      unstable.gtk3

      unstable.refine
    ];

    services.flatpak = {
      packages = [
        "org.gnome.Chess"
        "com.leinardi.gst"
      ];
      # The new overrides.settings syntax doesn't seem to work so we're using the old overrides syntax
      # https://github.com/gmodena/nix-flatpak/issues/211
      overrides = {
        # Force gst to use the Adwaita dark theme.
        "com.leinardi.gst".Environment = {
          GTK_THEME = "Adwaita:dark";
        };
      };
    };
  };
}
