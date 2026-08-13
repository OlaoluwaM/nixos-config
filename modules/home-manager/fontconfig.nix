{
  config,
  lib,
  pkgs,
  ...
}:

# Inspired by https://codeberg.org/SeniorMatthew/nixos/src/branch/main/modules
let
  cfg = config.local.fonts;

  fontOption =
    {
      family,
      name ? family,
      size,
      fallbacks,
      description,
    }:
    {
      family = lib.mkOption {
        type = lib.types.str;
        default = family;
        description = "${description} font family.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "${description} font name, including style when needed.";
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = size;
        description = "${description} font size.";
      };

      fallbacks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = fallbacks;
        description = "Fallback families for ${lib.toLower description} text.";
      };
    };

  # Every configured font role. Used to build named-family fallback aliases so
  # that requests for a preferred family by name still resolve when that family
  # is not installed.
  fontRoles = [
    cfg.ui
    cfg.document
    cfg.mono
    cfg.shell
  ];

  # A preferred family can be shared by several roles (UI, document and shell
  # all use SF Pro Display), so collapse to one alias per family and merge those
  # roles' fallback lists de-duplicated, in fontRoles order — so when roles
  # disagree (document wants serif fallbacks), the earlier role's chain wins.
  aliasFamilies = lib.unique (map (role: role.family) fontRoles);
  fallbacksFor =
    family:
    lib.unique (
      lib.concatMap (role: role.fallbacks) (lib.filter (role: role.family == family) fontRoles)
    );

  # One <alias> that makes fontconfig fall back to our fallback families whenever
  # a preferred family (e.g. SF Pro Display, Berkeley Mono) is requested by name
  # but is not installed. <prefer> prepends the fallbacks to the pattern's family
  # list, but with weak binding (the alias default), while the family the app
  # asked for keeps strong binding — and fontconfig ranks strong family matches
  # ahead of weak ones, so the preferred font still wins whenever it is
  # installed. This covers every app that requests these families by name
  # (hyprlock, GTK, a future shell UI), not just the generic serif/sans/monospace
  # aliases handled by defaultFonts.
  familyAlias =
    family:
    lib.concatStringsSep "\n" (
      [
        "  <alias>"
        "    <family>${family}</family>"
        "    <prefer>"
      ]
      ++ map (f: "      <family>${f}</family>") (fallbacksFor family)
      ++ [
        "    </prefer>"
        "  </alias>"
      ]
    );

  namedFamilyFallbacks = lib.concatMapStringsSep "\n" familyAlias aliasFamilies;
in
{
  options.local.fonts = {
    ui = fontOption {
      family = "SF Pro Display";
      name = "SF Pro Display Medium";
      size = 10;
      fallbacks = [
        "Noto Sans"
        "DejaVu Sans"
      ];
      description = "Interface";
    };

    document = fontOption {
      family = "SF Pro Display";
      name = "SF Pro Display Medium";
      size = 10;
      fallbacks = [
        "Noto Serif"
        "DejaVu Serif"
      ];
      description = "Document";
    };

    mono = fontOption {
      family = "Berkeley Mono";
      name = "Berkeley Mono Medium";
      size = 10;
      fallbacks = [
        "Noto Sans Mono"
        "DejaVu Sans Mono"
      ];
      description = "Monospace";
    };

    shell = fontOption {
      family = "SF Pro Display";
      name = "SF Pro Display Medium";
      size = 13;
      fallbacks = [
        "Noto Sans"
        "DejaVu Sans"
      ];
      description = "Shell";
    };
  };

  config = {
    home.packages = with pkgs; [
      noto-fonts
      dejavu_fonts
      noto-fonts-color-emoji
    ];

    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ cfg.document.family ] ++ cfg.document.fallbacks;
        sansSerif = [ cfg.ui.family ] ++ cfg.ui.fallbacks;
        monospace = [ cfg.mono.family ] ++ cfg.mono.fallbacks;
        emoji = [ "Noto Color Emoji" ];
      };

      # Bind each preferred family to its fallback chain so a missing preferred
      # font degrades to Noto/DejaVu instead of an undefined substitution.
      configFile.named-family-fallbacks = {
        enable = true;
        priority = 51;
        label = "named-family-fallbacks";
        text = ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
          <fontconfig>
          ${namedFamilyFallbacks}
          </fontconfig>
        '';
      };

      configFile.berkeley-mono-spacing = {
        enable = true;
        priority = 50;
        label = "berkeley-mono-spacing";
        text = ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
          <fontconfig>
            <match target="scan">
              <test name="family">
                <string>Berkeley Mono</string>
              </test>
              <edit name="spacing" mode="assign">
                <int>100</int>
              </edit>
            </match>

            <match target="scan">
              <test name="family">
                <string>Berkeley Mono Variable</string>
              </test>
              <edit name="spacing" mode="assign">
                <int>100</int>
              </edit>
            </match>
          </fontconfig>
        '';
      };
    };
  };
}
