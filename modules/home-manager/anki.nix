{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.anki;
in
{
  options.local.anki = {
    enable = lib.mkEnableOption "Anki with Nix-managed add-ons";
  };

  config = lib.mkIf cfg.enable {
    # The withAddons wrapper loads add-ons from a read-only store directory and
    # disables Anki's add-on manager, so every add-on and every config value an
    # add-on would normally save from its own menus has to be declared here.
    home.packages = [
      (unstable.anki.withAddons [
        # Yanki syncs flashcards from Obsidian over AnkiConnect, so Obsidian's
        # origin has to be allowed here.
        (unstable.ankiAddons.anki-connect.withConfig {
          config.webCorsOriginList = [
            "http://localhost"
            "app://obsidian.md"
          ];
        })
        # Keys not listed keep FSRS Helper's defaults.
        (unstable.ankiAddons.fsrs4anki-helper.withConfig {
          config = {
            # Most reviews happen on the phone, where add-ons don't run, so
            # siblings are spread out when the desktop syncs those reviews in.
            auto_disperse_after_sync = true;
            show_steps_stats = true;
            # Hides the "Rate add-on" menu item, whose click handler writes
            # this flag back and so trips the locked-config warning.
            has_rated = true;
          };
        })
      ])
    ];
  };
}
