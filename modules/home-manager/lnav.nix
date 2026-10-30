{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.lnav;
  jsonFormat = pkgs.formats.json { };

  catppuccinLnav = pkgs.fetchFromGitHub {
    owner = "ninetailedtori";
    repo = "catppuccin-lnav";
    rev = "bb53843bb2a26665e582160f76ba0d6c13242663";
    hash = "sha256-wo7W3Rfekba8SH8u8Y4OGosqVfw9/m/RtzMw1qMfJYA=";
  };

  themeOverrides = jsonFormat.generate "lnav-catppuccin-overrides.json" {
    ui = {
      theme = "catppuccin-mocha";
      theme-defs.catppuccin-mocha = {
        styles = {
          alt-text.background-color = "$surface0";
          time-ago.bold = true;
          timeline-bar.background-color = "$teal";
        };
        status-styles = {
          warn.color = "$peach";
          inactive-warn.color = "$peach";
          alert-title = {
            color = "$red";
            bold = true;
          };
        };
      };
    };
  };

  theme = pkgs.runCommand "lnav-catppuccin.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -s '.[0] * .[1]' ${catppuccinLnav}/catppuccin.json ${themeOverrides} > $out
  '';
in
{
  options.local.lnav = {
    enable = lib.mkEnableOption "lnav configuration";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ unstable.lnav ]; }

      (lib.mkIf config.local.catppuccin.enable {
        xdg.configFile."lnav/configs/home-manager/catppuccin.json".source = theme;
      })
    ]
  );
}
