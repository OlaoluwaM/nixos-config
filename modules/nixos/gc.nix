{
  config,
  lib,
  ...
}:
let
  cfg = config.local.gc;
in
{
  options.local.gc = {
    enable = lib.mkEnableOption "Enable the GC module.";
  };

  config = lib.mkIf cfg.enable {
    # Per https://discourse.nixos.org/t/no-space-left-on-boot/24019/7
    nix.gc = {
      automatic = true;
      randomizedDelaySec = "14m";
      options = "--delete-older-than 10d";
    };
  };
}
