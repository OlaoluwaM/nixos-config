{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.delta;
in
{
  options.local.delta = {
    enable = lib.mkEnableOption "delta configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.delta.enable = true;

    programs.delta = {
      enable = true;
      package = unstable.delta;
    };
  };
}
