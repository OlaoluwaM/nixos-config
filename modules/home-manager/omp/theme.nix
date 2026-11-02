{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.local.omp;

  catppuccinTheme =
    let
      upstream = (lib.importJSON "${inputs.omp}/packages/tui/src/theme/defaults.json").dark-catppuccin;
      accentTokens = [
        "accent"
        "mdHeading"
        "mdListBullet"
        "statusLineSubagents"
      ];
    in
    upstream
    // {
      name = "catppuccin-mocha";
      colors = upstream.colors // lib.genAttrs accentTokens (_: config.catppuccin.accent);
      symbols.overrides."sep.space" = "";
    };

in
{
  config = lib.mkIf cfg.enable {
    programs.omp.settings.theme.dark =
      if config.local.catppuccin.enable then catppuccinTheme.name else "titanium";

    home.file = {
      ".omp/agent/themes/${catppuccinTheme.name}.json" = lib.mkIf config.local.catppuccin.enable {
        text = builtins.toJSON catppuccinTheme;
      };
    };
  };
}
