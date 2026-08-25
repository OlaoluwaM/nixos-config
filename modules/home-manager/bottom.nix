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
      # Lavender selection accent over the catppuccin module's pink border and
      # mauve selection, matching wifitui's Primary and the rice's accent
      # direction. This is the highlight silere's vitals tiles land on when
      # they deep-link a widget (silere.nix's systemMonitorCommand). mkForce
      # because catppuccin.bottom renders these same keys.
      settings.styles.widgets = {
        selected_border_color = lib.mkForce "#b4befe"; # Lavender
        selected_text.bg_color = lib.mkForce "#b4befe"; # Lavender
      };
    };
  };
}
