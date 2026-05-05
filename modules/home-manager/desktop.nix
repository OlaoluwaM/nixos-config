{
  config,
  lib,
  ...
}:
let
  cfg = config.local.desktop;
in
{
  imports = [
    ./gnome
    ./hyprland
  ];
  # This option should mirror what's in ../../modules/nixos/desktop.nix
  options.local.desktop = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "none"
      ];
      default = "gnome";
      example = "hyprland";
      description = ''
        Home Manager desktop profile to enable for this user.

        Use "gnome" for GNOME user packages and settings, "hyprland" for
        Hyprland user packages and settings, and "none" for users without a
        local graphical session.
      '';
    };
  };

  config = {
    local.gnome.enable = cfg.profile == "gnome";
    local.hyprland.enable = cfg.profile == "hyprland";
  };
}
