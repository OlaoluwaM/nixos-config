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
          # We had an issue with satty where taking a screenshot of vicinae would hog keyboard input so trying to "ESC" or "ENTER" while both satty and vicinae were active would not work as expected. We'd need to close vicinae before satty could get keyboard input again. This option only passes keyboard input to vicinae when it is in focus. This way if we have satty up, it can correctly take input without interference from vicinae.
          keyboard_interactivity = "on_demand";
        };
      };
    };
  };
}
