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
  };
}
