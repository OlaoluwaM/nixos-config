{
  config,
  lib,
  ...
}:
let
  cfg = config.local.gnome;
in
{
  options.local.gnome = {
    enable = lib.mkEnableOption "GNOME system configuration";
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Enable the GVfs daemon with Google backend support
    services.gvfs.enable = true;

    # Ensure Gnome Online Accounts daemon is active
    services.gnome.gnome-online-accounts.enable = true;

    services.gnome.gnome-keyring.enable = true;

    services.switcherooControl.enable = true;
  };
}
