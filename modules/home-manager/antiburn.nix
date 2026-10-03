{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.antiburn;
  antiburnPackage = pkgs.callPackage ../../pkgs/antiburn { };

  autostartEntry = pkgs.makeDesktopItem {
    name = "antiburn";
    desktopName = "Antiburn";
    exec = "${lib.getExe antiburnPackage} --background";
    onlyShowIn = [ "GNOME" ];
    terminal = false;
  };
in
{
  options.local.antiburn = {
    enable = lib.mkEnableOption "antiburn configuration";
  };

  config = lib.mkIf cfg.enable {

    home.packages = [ antiburnPackage ];

    xdg.autostart = lib.mkIf config.local.gnome.enable {
      enable = true;
      entries = [
        "${autostartEntry}/share/applications/antiburn.desktop"
      ];
    };

    systemd.user.services.antiburn = lib.mkIf config.local.hyprland.enable {
      Unit = {
        Description = "Antiburn session usage monitor";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };

      Install.WantedBy = [ config.wayland.systemd.target ];

      Service = {
        ExecStart = "${lib.getExe antiburnPackage} --background";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
