{ config, lib, ... }:

let
  cfg = config.local.omp;
in
{
  config = lib.mkIf cfg.enable {
    programs.omp.settings.statusLine = {
      preset = "custom";
      separator = "none";
      transparent = true;
      leftSegments = [
        "path"
        "git"
        "model"
        "mode"
      ];
      rightSegments = [
        "context_pct"
        "cost"
        "time_spent"
        "time"
      ];
      segmentOptions.time.format = "24h";
    };
  };
}
