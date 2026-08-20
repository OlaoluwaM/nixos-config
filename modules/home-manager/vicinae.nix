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

    systemd.target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = ''
        User systemd target that starts and stops the Vicinae service.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    catppuccin.vicinae.enable = true;

    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
        target = cfg.systemd.target;
      };

      # useLayerShell
      settings = {
        launcher_window.layer_shell = {
          enabled = true;
          keyboard_interactivity = "on_demand";
        };
      };
    };
  };
}
