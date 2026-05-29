{
  config,
  lib,
  ...
}:

let
  cfg = config.local.theme;

  colorOption =
    default: description:
    lib.mkOption {
      type = lib.types.str;
      inherit default description;
    };

  presets = {
    noctalia = {
      base = "#070722";
      surfaceVariant = "#161640";
      surfaceHover = "#20204d";
      surfaceDeep = "#040414";
      outline = "#21215F";
      text = "#f3edf7";
      textSecondary = "#7c80b4";
      textDim = "#4a4d7a";
      primary = "#a9aefe";
      secondary = "#fff59b";
      error = "#FD4663";
      success = "#7AE8A0";
      warning = "#FFD166";
      primaryForeground = "#0e0e43";
      secondaryForeground = "#0e0e43";
      errorForeground = "#0e0e43";
      metricCpu = "#7BA4FF";
      metricMemory = "#9BFECE";
      metricTemperature = "#FFB87A";
      scrim = "#000000";
      shadowColor = "#040414dd";
      lockBackground = "#040414";
      lockRingColor = "#a9aefe";
      lockInputColor = "#0c0c28";
      lockTextColor = "#f3edf7";
      lockCheckColor = "#a9aefe";
      lockFailColor = "#FD4663";
      lockClockColor = "#f3edf7";
      lockDateColor = "#b8bde0";
    };

    catppuccin-mocha = {
      base = "#1e1e2e";
      surfaceVariant = "#313244";
      surfaceHover = "#3a3c52";
      surfaceDeep = "#15161a";
      outline = "#45475a";
      text = "#cdd6f4";
      textSecondary = "#a6adc8";
      textDim = "#6c7086";
      primary = "#b4befe";
      secondary = "#cba6f7";
      error = "#f38ba8";
      success = "#a6e3a1";
      warning = "#f9e2af";
      primaryForeground = "#11111b";
      secondaryForeground = "#11111b";
      errorForeground = "#11111b";
      metricCpu = "#89b4fa";
      metricMemory = "#94e2d5";
      metricTemperature = "#fab387";
      scrim = "#000000";
      shadowColor = "#11111bdd";
      lockBackground = "#11111b";
      lockRingColor = "#b4befe";
      lockInputColor = "#181825";
      lockTextColor = "#cdd6f4";
      lockCheckColor = "#89b4fa";
      lockFailColor = "#f38ba8";
      lockClockColor = "#f5e0dc";
      lockDateColor = "#cdd6f4";
    };
  };

  selected = presets.${cfg.preset};
in
{
  options.local.theme = {
    preset = lib.mkOption {
      type = lib.types.enum [
        "noctalia"
        "catppuccin-mocha"
      ];
      default = "noctalia";
      description = "Color theme preset. Individual colors can be overridden via local.theme.colors.";
    };

    colors = {
      base = colorOption selected.base "Main background color";
      surfaceVariant = colorOption selected.surfaceVariant "Raised cards and capsule fills";
      surfaceHover = colorOption selected.surfaceHover "Neutral hover surface color";
      surfaceDeep = colorOption selected.surfaceDeep "Deep decorative surface (e.g. media disc)";
      outline = colorOption selected.outline "Border color";
      text = colorOption selected.text "Primary text color";
      textSecondary = colorOption selected.textSecondary "Muted/secondary text";
      textDim = colorOption selected.textDim "Dimmed text";
      primary = colorOption selected.primary "Primary accent color";
      secondary = colorOption selected.secondary "Secondary accent color";
      error = colorOption selected.error "Error/danger color";
      success = colorOption selected.success "Success/healthy color";
      warning = colorOption selected.warning "Warning/caution color";
      primaryForeground = colorOption selected.primaryForeground "Text on primary accent";
      secondaryForeground = colorOption selected.secondaryForeground "Text on secondary accent";
      errorForeground = colorOption selected.errorForeground "Text on error/danger color";
      metricCpu = colorOption selected.metricCpu "CPU metric color";
      metricMemory = colorOption selected.metricMemory "Memory metric color";
      metricTemperature = colorOption selected.metricTemperature "Temperature metric color";
      scrim = colorOption selected.scrim "Modal scrim/backdrop (applied with opacity)";
      shadowColor = colorOption selected.shadowColor "Window shadow color (8-char rgba)";
      lockBackground = colorOption selected.lockBackground "Lock screen fallback background";
      lockRingColor = colorOption selected.lockRingColor "Lock screen input ring";
      lockInputColor = colorOption selected.lockInputColor "Lock screen input field background";
      lockTextColor = colorOption selected.lockTextColor "Lock screen input text";
      lockCheckColor = colorOption selected.lockCheckColor "Lock screen checking state";
      lockFailColor = colorOption selected.lockFailColor "Lock screen failure state";
      lockClockColor = colorOption selected.lockClockColor "Lock screen clock color";
      lockDateColor = colorOption selected.lockDateColor "Lock screen date color";
    };
  };
}
