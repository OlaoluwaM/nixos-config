{
  config,
  lib,
  pkgs,
  ...
}:

# HM module for hyprland packages and configuration
# Purposely kept bear bones for now
let
  cfg = config.local.hyprland;
in
{
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
  ];

  options.local.hyprland = {
    enable = lib.mkEnableOption "Hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      hyprpaper
    ];

    # xdg-desktop-portal 1.17+ requires an explicit backend selection when
    # portals are enabled. Hyprland handles compositor-specific portals such as
    # screen sharing, while GTK covers generic interfaces Hyprland does not implement, such as the file picker.
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
