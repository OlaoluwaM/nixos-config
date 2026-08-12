{ config, lib, ... }:

let
  cfg = config.local.gnome;
  enableAsusRogKeybindings = config.local.capabilities.input.asusRogKeys;

  gvariant = lib.hm.gvariant;
  inherit (gvariant) mkTuple mkVariant;

  uint32 = gvariant.mkUint32;

  mkWorldClock =
    {
      cityCoordinates,
      name,
      stationCode,
      stationCoordinates,
    }:
    mkVariant (mkTuple [
      (uint32 2)
      (mkVariant (mkTuple [
        name
        stationCode
        true
        [ (mkTuple stationCoordinates) ]
        [ (mkTuple cityCoordinates) ]
      ]))
    ]);

  worldClocks = [
    (mkWorldClock {
      name = "San Francisco";
      stationCode = "KOAK";
      stationCoordinates = [
        0.65832848982162007
        (-2.133408063190589)
      ];
      cityCoordinates = [
        0.659296885757089
        (-2.1366218601153339)
      ];
    })
    (mkWorldClock {
      name = "Birmingham";
      stationCode = "EGBB";
      stationCoordinates = [
        0.91542519267102596
        (-0.030252367883470872)
      ];
      cityCoordinates = [
        0.91571608669745586
        (-0.033452149814322159)
      ];
    })
    (mkWorldClock {
      name = "Lagos";
      stationCode = "DNMM";
      stationCoordinates = [
        0.11490083660519584
        0.058177635915380145
      ];
      cityCoordinates = [
        0.11266147445513201
        0.059063373057474736
      ];
    })
  ];

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
        locations = gvariant.mkEmptyArray gvariant.type.variant;
      };

      "org/gnome/shell/world-clocks" = {
        locations = worldClocks;
      };
    };
  };
}
