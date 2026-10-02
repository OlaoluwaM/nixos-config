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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ antiburnPackage ];
      }

      (lib.mkIf config.local.gnome.enable {
        xdg.autostart = {
          enable = true;
          entries = [
            "${autostartEntry}/share/applications/antiburn.desktop"
          ];
        };
      })

      (lib.mkIf config.local.hyprland.enable {
        systemd.user.services.antiburn = {
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
      })
    ]
  );
}
