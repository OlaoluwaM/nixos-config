{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.fzf;
in
{
  options.local.fzf = {
    enable = lib.mkEnableOption "fzf configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.fzf.enable = true;

    programs.fzf = {
      enable = true;
      package = unstable.fzf;
      enableZshIntegration = true;
      defaultOptions = [ "--multi" ];
    };
  };
}
