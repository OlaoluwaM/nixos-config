{
  config,
  lib,
  pkgs,
  unstable,
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

    # For screen sharing and opening desktop apps
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
      ];
    };
  };
}
