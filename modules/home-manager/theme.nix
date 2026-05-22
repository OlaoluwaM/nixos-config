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
      surfaceVariant = "#1e1e2e";
      outline = "#21215F";
      text = "#f3edf7";
      textSecondary = "#7c80b4";
      textDim = "#4a4d7a";
      primary = "#a9aefe";
      secondary = "#fff59b";
      tertiary = "#9BFECE";
      error = "#FD4663";
      primaryContrast = "#0e0e43";
      tertiaryContrast = "#0e0e43";
      statsCpu = "#89b4fa";
      statsMem = "#94e2d5";
      statsTemp = "#fab387";
      statusGreen = "#a6e3a1";
      sliderBrightness = "#a6e3a1";
      sliderVolume = "#a6e3a1";
      batteryCardBg = "#111d15";
      batteryRing = "#a6e3a1";
      batteryRingBg = "#152a1e";
      powerProfileActive = "#f38ba8";
      shadowColor = "#11111bdd";
      lockFallbackBg = "#11111b";
      lockOuterColor = "#b4befe";
      lockInnerColor = "#181825";
      lockFontColor = "#cdd6f4";
      lockCheckColor = "#89b4fa";
      lockFailColor = "#f38ba8";
      lockClockColor = "#f5e0dc";
      lockDateColor = "#cdd6f4";
    };

    catppuccin-mocha = {
      base = "#1e1e2e";
      surfaceVariant = "#313244";
      outline = "#45475a";
      text = "#cdd6f4";
      textSecondary = "#a6adc8";
      textDim = "#6c7086";
      primary = "#b4befe";
      secondary = "#cba6f7";
      tertiary = "#94e2d5";
      error = "#f38ba8";
      primaryContrast = "#11111b";
      tertiaryContrast = "#11111b";
      statsCpu = "#89b4fa";
      statsMem = "#94e2d5";
      statsTemp = "#fab387";
      statusGreen = "#a6e3a1";
      sliderBrightness = "#f9e2af";
      sliderVolume = "#a6e3a1";
      batteryCardBg = "#181825";
      batteryRing = "#a6e3a1";
      batteryRingBg = "#11111b";
      powerProfileActive = "#f5c2e7";
      shadowColor = "#11111bdd";
      lockFallbackBg = "#11111b";
      lockOuterColor = "#b4befe";
      lockInnerColor = "#181825";
      lockFontColor = "#cdd6f4";
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
      outline = colorOption selected.outline "Border color";
      text = colorOption selected.text "Primary text color";
      textSecondary = colorOption selected.textSecondary "Muted/secondary text";
      textDim = colorOption selected.textDim "Dimmed text";
      primary = colorOption selected.primary "Primary accent color";
      secondary = colorOption selected.secondary "Secondary accent (lavender)";
      tertiary = colorOption selected.tertiary "Tertiary accent (hover)";
      error = colorOption selected.error "Error/danger color";
      primaryContrast = colorOption selected.primaryContrast "Text on primary accent";
      tertiaryContrast = colorOption selected.tertiaryContrast "Text on tertiary accent";
      statsCpu = colorOption selected.statsCpu "CPU stats color";
      statsMem = colorOption selected.statsMem "Memory stats color";
      statsTemp = colorOption selected.statsTemp "Temperature stats color";
      statusGreen = colorOption selected.statusGreen "Healthy/good status color";
      sliderBrightness = colorOption selected.sliderBrightness "Brightness slider fill";
      sliderVolume = colorOption selected.sliderVolume "Volume slider fill";
      batteryCardBg = colorOption selected.batteryCardBg "Battery card background";
      batteryRing = colorOption selected.batteryRing "Battery ring color";
      batteryRingBg = colorOption selected.batteryRingBg "Battery ring background";
      powerProfileActive = colorOption selected.powerProfileActive "Active power profile pill";
      shadowColor = colorOption selected.shadowColor "Window shadow color (8-char rgba)";
      lockFallbackBg = colorOption selected.lockFallbackBg "Lock screen fallback background";
      lockOuterColor = colorOption selected.lockOuterColor "Lock screen input ring";
      lockInnerColor = colorOption selected.lockInnerColor "Lock screen input field background";
      lockFontColor = colorOption selected.lockFontColor "Lock screen input text";
      lockCheckColor = colorOption selected.lockCheckColor "Lock screen checking state";
      lockFailColor = colorOption selected.lockFailColor "Lock screen failure state";
      lockClockColor = colorOption selected.lockClockColor "Lock screen clock color";
      lockDateColor = colorOption selected.lockDateColor "Lock screen date color";
    };
  };
}
