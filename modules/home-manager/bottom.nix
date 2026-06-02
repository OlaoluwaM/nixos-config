{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.bottom;
in
{
  options.local.bottom = {
    enable = lib.mkEnableOption "bottom configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.bottom.enable = true;

    programs.bottom = {
      enable = true;
      package = unstable.bottom;
    };
  };
}
