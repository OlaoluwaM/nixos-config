{
  config,
  lib,
  ...
}:

let
  cfg = config.local.bat;
in
{
  options.local.bat = {
    enable = lib.mkEnableOption "bat configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;

      config = {
        style = "numbers,header,grid,snip";
        map-syntax = [ ".ignore:Git Ignore" ];
      };
    };
  };
}
