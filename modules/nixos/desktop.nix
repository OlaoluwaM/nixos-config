{
  config,
  lib,
  ...
}:
let
  cfg = config.local.desktop;

  enableDesktop = cfg.profile != "none";
in
{
  imports = [
    ./gnome.nix
    ./hyprland.nix
  ];

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
        Desktop profile to enable for this host.

        Use "gnome" for the full GNOME desktop, "hyprland" for the Hyprland
        Wayland compositor, and "none" for systems without a local graphical
        session.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf enableDesktop {
      security.polkit.enable = true;

      programs.seahorse.enable = true;
    })

    # Do not move these up because when profile is set to "none", the values of these options becomes a bit unclear
    {
      local.gnome.enable = cfg.profile == "gnome";
      local.hyprland.enable = cfg.profile == "hyprland";
    }
  ];
}
