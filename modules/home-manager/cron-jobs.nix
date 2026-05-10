{ config, pkgs, ... }:

let
  wallpapersDir = "${config.xdg.userDirs.pictures}/Wallpapers";

  compressWallpapers = pkgs.writeShellApplication {
    name = "compress-wallpapers";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.nodejs
    ];
    text = ''
      if [[ ! -f "${wallpapersDir}/compressWallpapers.mjs" ]]; then
        echo "compress-wallpapers: ${wallpapersDir}/compressWallpapers.mjs not found; skipping compression."
        exit 0
      fi

      cd "${wallpapersDir}"
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
