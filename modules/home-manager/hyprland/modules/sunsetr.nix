{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.hyprland;
  sunsetrPackage = unstable.sunsetr;
  sessionTarget = config.wayland.systemd.target;
in
{
  config = lib.mkIf cfg.enable {
    # sunsetr's config (~/.config/sunsetr/sunsetr.toml) is deliberately not
    # managed here. The daemon writes its own on first start (follow the sun,
    # location detected from the timezone), and afterwards the shell's Night
    # Light card and `sunsetr set` rewrite it, replacing even a store symlink
    # with a plain file. A Nix-rendered file would also have to carry
    # coordinates, because sunsetr refuses to start in sun mode without them.
    #
    # Its default dims the screen 10% at night. Running
    # `sunsetr set night_gamma=100` once turns that off.
    home.packages = [ sunsetrPackage ];

    # We create this unit to start sunsetr automatically when the Hyprland session starts
    systemd.user.services.sunsetr = {
      Unit = {
        Description = "sunsetr - night light for the Hyprland session";
        After = [ sessionTarget ];
        PartOf = [ sessionTarget ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Install.WantedBy = [ sessionTarget ];

      Service = {
        ExecStart = "${sunsetrPackage}/bin/sunsetr";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
}
