{
  config,
  lib,
  ...
}:

let
  cfg = config.local.vicinae;
in
{
  options.local.vicinae = {
    enable = lib.mkEnableOption "vicinae configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.vicinae.enable = true;

    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
      };
      # useLayerShell
      settings = {
        launcher_window.layer_shell.enabled = true;
      };
    };
  };
}
