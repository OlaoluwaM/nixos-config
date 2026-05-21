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
        require small Hyprland config changes. Leave this false for the first
        migration step.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = cfg.withUWSM;
    };

    # Necessary since Nautilus is a gnome app
    programs.dconf.enable = true;

    # Login screen replacement for gdm on hyprland
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };

    # Does not install hyprlock or hypridle. Only allows a PAM service named `hyprlock` to authenticate the user on lock screen
    # We'd still want to configure hyprlock and hypridle in a home-manager module
    security.pam.services.hyprlock = { };

    # Nautilus uses GVfs for trash, removable devices, and common virtual file
    # systems. GNOME enables this for us; Hyprland does not.
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
