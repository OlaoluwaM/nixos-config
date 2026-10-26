{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.greet;

  # Replacements for sysc-greet themes, keyed by file name. sysc-greet matches
  # themes by `name` and loads ~/.config/sysc-greet/themes (see
  # `greeterThemeDir` for whose ~ that is) after its own, with the later one
  # winning; upstream documents this as the way to change a theme. Reusing
  # the upstream name replaces the theme in place, so saved preferences and
  # the name-matched theme wallpapers keep working.
  #
  # Field labels render in `primary` when focused and `fg_secondary` when not,
  # and several upstream palettes make those nearly identical in brightness
  # (or make the unfocused one brighter), which hides Tab focus. Every entry
  # here exists to dim `fg_secondary`.
  #
  # Entries for themes that ship as TOML (`themes/` in the pinned source) are
  # merged over the upstream file, so upstream palette changes still flow
  # through on re-lock. Themes compiled into the binary have no file to merge
  # over, so their entries spell out every colour, mirroring the runtime
  # palette in cmd/sysc-greet/theme.go (warning/danger are its global defaults
  # and border_focus follows primary).
  #
  # Replacing a built-in swaps its hand-tuned background-animation palettes
  # (Matrix, Fire, ...) for ones derived from these fields; `bg_active` comes
  # from each built-in's own animation palette to stay close.
  greeterThemes = {
    # #ffffff vs #e0e0e0 upstream (~1.3:1). #707070 is ~4.9:1 against the
    # focused white and ~4.2:1 against the black background.
    void.colors.fg_secondary = "#707070";

    # Upstream unfocused #cccccc vs white is ~1.6:1; #707070 matches Void.
    dark = {
      name = "Dark";
      colors = {
        bg_base = "#000000";
        bg_active = "#333333";
        primary = "#ffffff";
        secondary = "#ffffff";
        accent = "#808080";
        warning = "#f59e0b";
        danger = "#ef4444";
        fg_primary = "#ffffff";
        fg_secondary = "#707070";
        fg_muted = "#666666";
        border_focus = "#ffffff";
      };
    };

    # Upstream unfocused Subtext1 #bac2de is brighter than the focused Mauve
    # #cba6f7 (~1.15:1). Overlay0 #6c7086 is ~2.4:1 against Mauve, and the
    # grey-vs-violet hue shift adds to that.
    catppuccin = {
      name = "Catppuccin";
      colors = {
        bg_base = "#1e1e2e";
        bg_active = "#313244";
        primary = "#cba6f7";
        secondary = "#89b4fa";
        accent = "#a6e3a1";
        warning = "#f59e0b";
        danger = "#ef4444";
        fg_primary = "#cdd6f4";
        fg_secondary = "#6c7086";
        fg_muted = "#a6adc8";
        border_focus = "#cba6f7";
      };
    };

    # Upstream unfocused #a9b1d6 vs the focused Blue #7aa2f7 is ~1.2:1.
    # Comment #565f89 is ~2.5:1 against Blue and ~2.8:1 against the
    # background, the palette's own colour for de-emphasised text.
    tokyo-night = {
      name = "Tokyo Night";
      colors = {
        bg_base = "#1a1b26";
        bg_active = "#24283b";
        primary = "#7aa2f7";
        secondary = "#bb9af7";
        accent = "#9ece6a";
        warning = "#f59e0b";
        danger = "#ef4444";
        fg_primary = "#c0caf5";
        fg_secondary = "#565f89";
        fg_muted = "#565f89";
        border_focus = "#7aa2f7";
      };
    };
  };

  # Upstream documents custom themes as going in ~/.config/sysc-greet/themes
  # (per user) or /usr/share/sysc-greet/themes (system-wide). The ~ there is
  # the greeter account's home, /var/lib/greeter, not a login user's: the
  # login screen runs as `greeter` before anyone has logged in, so it never
  # reads a real user's home and Home Manager can't supply these. The
  # system-wide path is unusable here because the upstream module links
  # /usr/share/sysc-greet to the read-only package in the Nix store.
  greeterThemeDir = "/var/lib/greeter/.config/sysc-greet/themes";

  # sysc-greet silently skips a theme missing any of these, falling back to the
  # original, so fail at eval time instead.
  requiredThemeColors = [
    "bg_base"
    "bg_active"
    "primary"
    "secondary"
    "accent"
    "warning"
    "danger"
    "fg_primary"
    "fg_secondary"
    "fg_muted"
    "border_focus"
  ];

  mkThemeFile =
    file: entry:
    let
      upstreamFile = "${inputs.sysc-greet}/themes/${file}.toml";
      upstream = lib.optionalAttrs (builtins.pathExists upstreamFile) (
        builtins.fromTOML (builtins.readFile upstreamFile)
      );
      theme = lib.recursiveUpdate upstream entry;
      missing = lib.filter (c: !((theme.colors or { }) ? ${c})) requiredThemeColors;
    in
    assert lib.assertMsg (
      theme ? name && missing == [ ]
    ) "sysc-greet theme '${file}' needs a name and all colour fields (missing: ${toString missing})";
    (pkgs.formats.toml { }).generate "sysc-greet-theme-${file}.toml" theme;
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

          # `L+` re-points each link at the current generation's store file on
          # every boot and switch, so the themes can't drift.
          "d /var/lib/greeter/.config 0755 greeter greeter -"
          "d /var/lib/greeter/.config/sysc-greet 0755 greeter greeter -"
          "d ${greeterThemeDir} 0755 greeter greeter -"
        ]
        ++ lib.mapAttrsToList (
          file: entry: "L+ ${greeterThemeDir}/${file}.toml - - - - ${mkThemeFile file entry}"
        ) greeterThemes;

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
