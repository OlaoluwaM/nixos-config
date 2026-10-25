{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.greet;
in
{
  options.local.greet = {
    enable = lib.mkEnableOption "Enable sysc-greet. Otherwise use regular greetd";
  };

  config = lib.mkIf config.local.hyprland.enable (
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        services.sysc-greet = {
          enable = true;
          compositor = "hyprland"; # or "cagebreak", "sway", "mango", "hyprland" (0.55+)
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/greeter/.cache/sysc-greet 0700 greeter greeter -"
          ''f /var/lib/greeter/.cache/sysc-greet/preferences 0600 greeter greeter - {"session":"Hyprland"}''
        ];

      })

      (lib.mkIf (!cfg.enable) {
        # Login screen replacement for GDM in the Hyprland profile.
        #
        # `start-hyprland` is upstream's launch wrapper (shipped in the hyprland
        # package). It prepares the session environment (XDG vars, D-Bus/systemd
        # activation-environment imports) that xdg-desktop-portal and screen
        # sharing depend on; launching the bare `Hyprland` binary skips that and
        # makes recent Hyprland versions warn at startup.
        services.greetd = {
          enable = true;
          settings.default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${config.programs.hyprland.package}/bin/start-hyprland";
            user = "greeter";
          };
        };

        security.pam.services = {
          greetd.enableGnomeKeyring = true;
        };
      })
    ]
  );
}
