{
  config,
  lib,
  pkgs,
  ...
}:

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
