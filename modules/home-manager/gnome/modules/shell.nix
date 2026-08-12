{ config, lib, ... }:

let
  cfg = config.local.gnome;
  enableAsusRogKeybindings = config.local.capabilities.input.asusRogKeys;

  gvariant = lib.hm.gvariant;
  inherit (gvariant) mkTuple mkVariant;

  uint32 = gvariant.mkUint32;

  minneapolisWeatherLocation = mkVariant (mkTuple [
    (uint32 2)
    (mkVariant (mkTuple [
      "Minneapolis"
      "KMSP"
      true
      [
        (mkTuple [
          0.783357105556996
          (-1.6271510710263237)
        ])
      ]
      [
        (mkTuple [
          0.78504848668181115
          (-1.627761011240018)
        ])
      ]
    ]))
  ]);

  sanFranciscoWorldClock = mkVariant (mkTuple [
    (uint32 2)
    (mkVariant (mkTuple [
      "San Francisco"
      "KOAK"
      false
      [
        (mkTuple [
          0.65832848982162007
          (-2.133408063190589)
        ])
      ]
      [
        (mkTuple [
          0.65832848982162007
          (-2.133408063190589)
        ])
      ]
    ]))
  ]);

  favoriteApps = [
    "firefox.desktop"
    "obsidian.desktop"
    "kitty.desktop"
    "com.obsproject.Studio.desktop"
    "com.github.neithern.g4music.desktop"
  ]
  ++ lib.optionals enableAsusRogKeybindings [
    "rog-control-center.desktop"
  ];
in
{
  config = lib.mkIf cfg.enable {
    programs.gnome-shell.enable = true;

    dconf.settings = {
      "org/gnome/shell" = {
        disabled-extensions = [ "background-logo@fedorahosted.org" ];
        favorite-apps = favoriteApps;
      };

      "org/gnome/shell/weather" = {
        automatic-location = true;
        locations = [ minneapolisWeatherLocation ];
      };

      "org/gnome/shell/world-clocks" = {
        locations = [ sanFranciscoWorldClock ];
      };
    };
  };
}
