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
  imports = [
    ./lnav.nix
  ];

  options.local.isd = {
    enable = lib.mkEnableOption "isd configuration";
  };

  config = lib.mkIf cfg.enable {
    local.lnav.enable = lib.mkDefault true;

    home.packages = [
      pkgs.isd
      pager
    ];

    xdg.configFile."isd_tui/config.yaml".source = yamlFormat.generate "isd-config.yaml" {
      theme = "terminal-derived-theme";
      default_pager = pagerExe;
      journal_pager = pagerExe;
    };
  };
}
