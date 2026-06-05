{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.yazi;
in
{
  options.local.yazi = {
    enable = lib.mkEnableOption "yazi configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.yazi.enable = true;

    programs.yazi = {
      enable = true;
      package = unstable.yazi;
      enableZshIntegration = true;
      settings = {
        log = {
          enabled = false;
        };
        mgr = {
          show_hidden = true;
          show_symlink = true;
        };
      };
    };
  };
}
