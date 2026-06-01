{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.lsd;
in
{
  options.local.lsd = {
    enable = lib.mkEnableOption "lsd configuration";
  };

  config = lib.mkIf cfg.enable {
    catppucin.lsd.enable = true;

    programs.lsd = {
      enable = true;
      package = unstable.lsd;
      enableZshIntegration = true;
    };
  };
}
