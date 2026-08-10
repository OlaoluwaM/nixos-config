{
  config,
  lib,
  pkgs,
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
    catppuccin.bat.enable = true;

    programs.bat = {
      enable = true;

      # The batgrep/batman/batwatch/... companion scripts belong to bat, so
      # this module owns their installation rather than home.packages.
      extraPackages = [ pkgs.bat-extras.core ];

      config = {
        style = "numbers,header,grid,snip";
        map-syntax = [ ".ignore:Git Ignore" ];
      };
    };
  };
}
