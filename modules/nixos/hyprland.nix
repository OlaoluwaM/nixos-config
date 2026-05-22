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

    withUWSM = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to launch Hyprland through UWSM.

        UWSM gives Hyprland better systemd user-session integration, but may
        require launch-command and service-startup changes. Leave this false
        while greetd starts Hyprland directly.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # This enables the compositor package, the Hyprland session files, and
    # XWayland support for older apps that still speak X11.
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = cfg.withUWSM;
    };

    # Nautilus and other GTK/GNOME apps store settings in dconf. GNOME enables
    # this automatically; a standalone Hyprland session needs it explicitly.
    programs.dconf.enable = true;

    # Login screen replacement for GDM in the Hyprland profile.
    #
    # This command intentionally starts Hyprland directly because withUWSM is
    # false by default. If local.hyprland.withUWSM is enabled later, revisit
    # this command too; UWSM sessions are launched through `uwsm start ...`, not
    # plain `Hyprland`.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };

    # This does not install hyprlock or hypridle. It only allows a PAM service
    # named `hyprlock` to authenticate the user at the lock screen. The actual
    # lock/idle programs are configured in Home Manager.
    security.pam.services.hyprlock = { };

    # Nautilus uses GVfs for trash, removable devices, and common virtual file
    # systems. GNOME enables this for us; Hyprland does not.
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
