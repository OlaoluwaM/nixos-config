{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.lazygit;
in
{
  options.local.lazygit = {
    enable = lib.mkEnableOption "lazygit configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.lazygit.enable = true;

    programs.lazygit = {
      enable = true;
      package = unstable.lazygit;
      enableZshIntegration = true;
    };
  };
}
