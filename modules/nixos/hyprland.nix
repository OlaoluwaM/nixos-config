{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.hyprland;
in
{
  options.local.hyprland = {
    enable = lib.mkEnableOption "Hyprland system configuration";
  };

  config = lib.mkIf cfg.enable {
    # This enables the compositor package, the Hyprland session files, and
    # XWayland support for older apps that still speak X11.
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Nautilus and other GTK/GNOME apps store settings in dconf. GNOME enables
    # this automatically; a standalone Hyprland session needs it explicitly.
    programs.dconf.enable = true;

    # Login screen replacement for GDM in the Hyprland profile.
    #
    # `start-hyprland` is upstream's launch wrapper (shipped in the hyprland
    # package). It prepares the session environment (XDG vars, D-Bus/systemd
    # activation-environment imports) that xdg-desktop-portal and screen
    # sharing depend on; launching the bare `Hyprland` binary skips that and
    # makes recent Hyprland versions warn at startup.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${config.programs.hyprland.package}/bin/start-hyprland";
        user = "greeter";
      };
    };

    # This does not install hyprlock or hypridle. It only allows a PAM service
    # named `hyprlock` to authenticate the user at the lock screen. The actual
    # lock/idle programs are configured in Home Manager.
    security.pam.services = {
      hyprlock = { };

      greetd.enableGnomeKeyring = true;
    };

    # Nautilus uses GVfs for trash, removable devices, and common virtual file
    # systems. GNOME enables this for us; Hyprland does not.
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    xdg.portal = {
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];

      config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];

        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
  };
}
