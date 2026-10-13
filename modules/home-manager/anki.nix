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
      ])
    ];
  };
}
