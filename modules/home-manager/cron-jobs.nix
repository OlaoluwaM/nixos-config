{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;

  compressWallpapers = pkgs.writeShellApplication {
    name = "compress-wallpapers";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.nodejs
    ];
    text = ''
      cd "${home}/Pictures/wallpapers"
      node ./compressWallpapers.mjs
    '';
  };
in
{
  systemd.user.services = {
    compress-wallpapers = {
      Unit.Description = "Compress wallpaper images into a tarball";

      Service = {
        Type = "oneshot";
        ExecStart = "${compressWallpapers}/bin/compress-wallpapers";
      };
    };
  };

  systemd.user.timers = {
    compress-wallpapers = {
      Unit.Description = "Weekly wallpaper compression";

      Timer = {
        OnCalendar = "Sat 17:00";
        Persistent = true;
        Unit = "compress-wallpapers.service";
      };

      Install.WantedBy = [ "timers.target" ];
    };
  };
}
