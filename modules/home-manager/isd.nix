{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.isd;
  pager = unstable.lnav;
  pagerExe = lib.getExe pager;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.local.isd = {
    enable = lib.mkEnableOption "isd configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.isd
      pager
    ];

    # For security reasons we may not want to use lnav with systemd automatically. We can still pipe output to lnav though using `lnav -q`
    home.sessionVariables.PAGER = "${pagerExe} -q";

    xdg.configFile."isd/config.yaml".source = yamlFormat.generate "isd-config.yaml" {
      theme = "terminal-derived-theme";
      default_pager = pagerExe;
      journal_pager = pagerExe;
    };
  };
}
