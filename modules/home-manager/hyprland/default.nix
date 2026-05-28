{
  config,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# This is the entry point for the Home Manager side of the Hyprland profile.
# "Entry point" means other config files import this module, and this module
# imports the smaller Hyprland-related files below.
#
# The split is:
# - default.nix: shared packages, fonts, portals, file-manager plumbing
# - quickshell.nix: Hyprland config, top bar, keybinds, services, scripts
# - hyprlock.nix: lock-screen look and behavior
# - hypridle.nix: idle locking behavior
#
# Home Manager source/options:
# https://nix-community.github.io/home-manager/options.xhtml
let
  cfg = config.local.hyprland;
in
{
  # Import the focused modules that make up the riced Hyprland session.
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ./quickshell.nix
  ];

  options.local.hyprland = {
    # Creates the option local.hyprland.enable. Other files can set this to true
    # to enable the whole Home Manager Hyprland profile.
    enable = lib.mkEnableOption "Hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    # Baseline user packages for the Hyprland profile. These are not all visible
    # apps; some are fonts and Qt support libraries that make the UI render
    # correctly.
    home.packages = with pkgs; [
      # General font/icon support. The Quickshell bar should not depend on Nerd
      # Font glyph icons; it uses SVG icons instead. The symbols font is kept as
      # a broad fallback for terminal/app text that may still contain those
      # characters outside this shell.
      font-awesome
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-color-emoji

      # Qt Wayland/QML support. Quickshell is a Qt/QML program, so these help
      # editor tooling and Qt apps understand the Wayland session.
      libsForQt5.qtwayland
      nautilus
      qt6.qtdeclarative
      qt6.qtimageformats
      qt6.qtsvg
      qt6.qtwayland
    ];

    # udiskie watches removable drives. automount=true means USB drives can show
    # up automatically without manually running mount commands.
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
    };

    # xdg-desktop-portal 1.17+ requires an explicit backend selection when
    # portals are enabled. Hyprland handles compositor-specific portals such as
    # screen sharing, while GTK covers generic interfaces Hyprland does not implement, such as the file picker.
    #
    # Plain English: portals are the bridge apps use to ask the desktop for
    # things like screen sharing, screenshots, and file pickers in a Wayland
    # session.
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
