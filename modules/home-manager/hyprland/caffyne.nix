{
  config,
  inputs,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  types = lib.types;
  cfg = config.local.hyprland;
  caffyneCfg = cfg.shell.caffyne;
  caffyneEnabled = cfg.enable && cfg.shell.backend == "caffyne";
  hyprlandSessionTarget = config.wayland.systemd.target;
  system = pkgs.stdenv.hostPlatform.system;

  # Maintainer map for the declarative Caffyne integration:
  #
  # 1. The types and assertions below describe the subset of Caffyne's saved
  #    settings that this profile supports.
  # 2. The `to*Json` functions are the only translation layer between friendly
  #    Nix option names and Caffyne's on-disk JSON schema.
  # 3. `caffyneDurableConfig` contains only Nix-owned preferences. Do not add
  #    runtime state such as Do Not Disturb or idle timeouts to it.
  # 4. `seedCaffyneConfig` merges that object over Caffyne's writable file at
  #    activation time. Caffyne must retain write access because its settings
  #    UI replaces the whole file when any preference changes.
  #
  # When updating the Caffyne pin, inspect UserOptions.save(), the built-in bar
  # widget variants, and the desktop applet model before changing this module.
  # The schema check below catches serialized sections, but it cannot detect a
  # renamed widget, variant, theme preset, or placement field.

  # These values mirror the pinned bar implementation. Keeping them here makes
  # invalid layouts fail during Home Manager evaluation instead of at Caffyne
  # startup. Empty variant lists mean that the widget accepts no variant field.
  baseVariants = [
    "icon"
    "label"
    "icon+label"
  ];
  progressVariants = [
    "icon"
    "scale"
    "icon+label"
    "scale+label"
  ];
  barWidgetVariants = {
    Processes = progressVariants;
    Energy = progressVariants;
    Bluetooth = [ ];
    Notifications = [
      "icon"
      "icon+label"
    ];
    Settings = [
      "single"
      "default"
      "battery"
      "battery+percent"
    ];
    Clock = baseVariants;
    Media = [ ];
    Workspaces = [
      "dots"
      "numbers"
      "icons+pill"
    ];
    Weather = baseVariants;
    Volume = progressVariants;
    Tray = [ ];
    Calendar = baseVariants;
    Focused = [ ];
    Wifi = progressVariants;
    Session = [ ];
    Calculator = [ ];
    Keyboard = baseVariants;
    Brightness = progressVariants;
    Dash = baseVariants;
  };
  barWidgetNames = builtins.attrNames barWidgetVariants;
  barVariantNames = lib.unique (lib.concatLists (builtins.attrValues barWidgetVariants));
  desktopAppletNames = [
    "Energy"
    "Clock"
    "Calendar"
    "Media"
    "Processes"
    "Weather"
  ];

  barWidgetType = types.enum barWidgetNames;
  barVariantType = types.enum barVariantNames;
  widgetWithVariantType = types.submodule {
    options = {
      widget = lib.mkOption {
        type = barWidgetType;
        description = "Caffyne bar widget name.";
      };
      variant = lib.mkOption {
        type = types.nullOr barVariantType;
        default = null;
        description = "Optional Caffyne presentation variant for this widget.";
      };
    };
  };
  plainBarEntryType = types.oneOf [
    barWidgetType
    widgetWithVariantType
  ];
  barObjectEntryType = types.submodule {
    options = {
      type = lib.mkOption {
        type = types.nullOr (types.enum [ "group" ]);
        default = null;
        description = "Set to group when this entry contains grouped widgets.";
      };
      widget = lib.mkOption {
        type = types.nullOr barWidgetType;
        default = null;
        description = "Caffyne widget name for a single object entry.";
      };
      variant = lib.mkOption {
        type = types.nullOr barVariantType;
        default = null;
        description = "Optional presentation variant for a single widget entry.";
      };
      widgets = lib.mkOption {
        type = types.listOf plainBarEntryType;
        default = [ ];
        description = "Non-nested widgets shown in the group.";
      };
    };
  };
  barEntryType = types.oneOf [
    barWidgetType
    barObjectEntryType
  ];
  barType = types.submodule {
    options = {
      alignment = lib.mkOption {
        type = types.enum [
          "top"
          "bottom"
          "left"
          "right"
        ];
        default = "top";
        description = "Screen edge used by this Caffyne bar.";
      };
      floating = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether this bar uses Caffyne's floating presentation.";
      };
      floatingApplets = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether applet popups use the floating presentation.";
      };
      roundedEdges = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether the bar renders rounded outer edges.";
      };
      minimumWidth = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether the bar shrinks to its minimum content width.";
      };
      autoHide = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether the bar automatically hides.";
      };
      left = lib.mkOption {
        type = types.listOf barEntryType;
        default = [ ];
        description = "Ordered Caffyne entries in the bar's left section.";
      };
      center = lib.mkOption {
        type = types.listOf barEntryType;
        default = [ ];
        description = "Ordered Caffyne entries in the bar's center section.";
      };
      right = lib.mkOption {
        type = types.listOf barEntryType;
        default = [ ];
        description = "Ordered Caffyne entries in the bar's right section.";
      };
    };
  };
  monitorBarsType = types.submodule {
    options = {
      monitor = lib.mkOption {
        type = types.ints.unsigned;
        description = "Caffyne's numeric GDK monitor identifier.";
      };
      alignment = lib.mkOption {
        type = types.enum [
          "top"
          "bottom"
          "left"
          "right"
        ];
        default = "top";
        description = "Default screen edge for bars created on this monitor.";
      };
      floating = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Default floating mode for bars created on this monitor.";
      };
      bars = lib.mkOption {
        type = types.listOf barType;
        description = "Bars declared for this monitor.";
      };
    };
  };
  dashAppletType = types.submodule {
    options = {
      key = lib.mkOption {
        type = types.enum desktopAppletNames;
        description = "Caffyne desktop applet name.";
      };
      slot = lib.mkOption {
        type = types.ints.unsigned;
        description = "Dash applet slot.";
      };
    };
  };
  desktopCanvasEntryType = types.submodule {
    options = {
      key = lib.mkOption {
        type = types.enum desktopAppletNames;
        description = "Caffyne desktop applet name.";
      };
      gridX = lib.mkOption {
        type = types.ints.unsigned;
        description = "Last resolved horizontal grid coordinate.";
      };
      gridY = lib.mkOption {
        type = types.ints.unsigned;
        description = "Last resolved vertical grid coordinate.";
      };
      anchor = lib.mkOption {
        type = types.enum [
          "left"
          "center"
          "right"
        ];
        description = "Horizontal anchor used when the canvas is resized.";
      };
      offset = lib.mkOption {
        type = types.int;
        description = "Grid-column offset from the selected anchor.";
      };
      relativeY = lib.mkOption {
        type = types.numbers.between 0.0 1.0;
        description = "Vertical placement as a fraction from zero through one.";
      };
    };
  };

  isBarGroup = entry: builtins.isAttrs entry && (entry.type or null) == "group";
  barEntryName = entry: if builtins.isString entry then entry else entry.widget;
  barEntryVariant = entry: if builtins.isString entry then null else entry.variant;
  flattenBarEntry = entry: if isBarGroup entry then entry.widgets else [ entry ];
  allBars = lib.concatMap (monitorConfig: monitorConfig.bars) caffyneCfg.bars;
  rawBarEntries = lib.concatMap (bar: bar.left ++ bar.center ++ bar.right) allBars;
  allBarEntries = lib.concatMap (
    bar: lib.concatMap flattenBarEntry (bar.left ++ bar.center ++ bar.right)
  ) allBars;
  allBarGroups = lib.filter isBarGroup rawBarEntries;
  validBarEntryShape =
    entry:
    builtins.isString entry
    || (
      if isBarGroup entry then
        entry.widget == null && entry.variant == null && entry.widgets != [ ]
      else
        entry.type == null && entry.widget != null && entry.widgets == [ ]
    );
  validBarVariant =
    entry:
    let
      variant = barEntryVariant entry;
    in
    variant == null || builtins.elem variant barWidgetVariants.${barEntryName entry};
  invalidGroupPairs = [
    [
      "Settings"
      "Wifi"
    ]
    [
      "Settings"
      "Bluetooth"
    ]
    [
      "Settings"
      "Energy"
    ]
    [
      "Settings"
      "Volume"
    ]
    [
      "Settings"
      "Keyboard"
    ]
    [
      "Settings"
      "Session"
    ]
  ];
  validBarGroup =
    group:
    let
      names = map barEntryName group.widgets;
    in
    lib.all (
      pair:
      !(builtins.elem (builtins.elemAt pair 0) names && builtins.elem (builtins.elemAt pair 1) names)
    ) invalidGroupPairs;

  toPlainBarEntryJson =
    entry:
    if builtins.isString entry then
      entry
    else
      {
        inherit (entry) widget;
      }
      // lib.optionalAttrs (entry.variant != null) { inherit (entry) variant; };
  toBarEntryJson =
    entry:
    if isBarGroup entry then
      {
        type = "group";
        widgets = map toPlainBarEntryJson entry.widgets;
      }
    else
      toPlainBarEntryJson entry;
  toBarJson = bar: {
    inherit (bar) alignment;
    floating_bar = bar.floating;
    floating_applets = bar.floatingApplets;
    rounded_edges = bar.roundedEdges;
    min_width = bar.minimumWidth;
    auto_hide = bar.autoHide;
    left = map toBarEntryJson bar.left;
    center = map toBarEntryJson bar.center;
    right = map toBarEntryJson bar.right;
  };
  toMonitorBarsJson = monitorConfig: {
    inherit (monitorConfig) monitor alignment;
    floating_bar = monitorConfig.floating;
    bars = map toBarJson monitorConfig.bars;
  };
  toDesktopCanvasEntryJson = entry: {
    inherit (entry) key;
    grid_x = entry.gridX;
    grid_y = entry.gridY;
    ax = entry.anchor;
    dx = entry.offset;
    ry = entry.relativeY;
  };

  # This is the ownership boundary. Every field in this object is declarative
  # and is reasserted on each Home Manager activation. Sections omitted here
  # remain owned by Caffyne or by another module and survive the recursive merge.
  # Keep snake-case Caffyne field names inside this conversion block so callers
  # only need to understand the typed Nix options.
  caffyneDurableConfig = {
    user.avatar = caffyneCfg.avatar;
    bars.configs = map toMonitorBarsJson caffyneCfg.bars;
    theme = {
      light_theme = caffyneCfg.theme.light;
      dark_theme = caffyneCfg.theme.dark;
      active_accent = caffyneCfg.theme.activeAccent;
      is_dark = caffyneCfg.theme.darkMode;
      scheme_type = caffyneCfg.theme.scheme;
      inherit (caffyneCfg.theme) opacity blur;
      border_style = caffyneCfg.theme.border;
      font_monospace_style = caffyneCfg.theme.monospaceFont;
    };
    world_clocks.clocks = caffyneCfg.worldClocks;
    wallpaper.path = caffyneCfg.wallpaper;
    templates.enabled = caffyneCfg.enabledTemplates;
    desktop_applets.applets = map (entry: {
      inherit (entry) key slot;
    }) caffyneCfg.dashApplets;
    desktop_canvas.placements = lib.mapAttrs (
      _monitor: entries: map toDesktopCanvasEntryJson entries
    ) caffyneCfg.desktopCanvas;
  };
  caffyneDurableConfigFile =
    (pkgs.formats.json { }).generate "caffyne-durable-config.json"
      caffyneDurableConfig;

  monitorIds = map (monitorConfig: monitorConfig.monitor) caffyneCfg.bars;
  dashAppletKeys = map (entry: entry.key) caffyneCfg.dashApplets;
  desktopCanvasLists = builtins.attrValues caffyneCfg.desktopCanvas;
  unique = values: builtins.length (lib.unique values) == builtins.length values;
  caffyneAssertions = [
    {
      assertion = caffyneCfg.bars != [ ];
      message = "local.hyprland.shell.caffyne.bars must declare at least one monitor.";
    }
    {
      assertion = unique monitorIds;
      message = "local.hyprland.shell.caffyne.bars must use each monitor identifier at most once.";
    }
    {
      assertion = lib.all (monitorConfig: monitorConfig.bars != [ ]) caffyneCfg.bars;
      message = "Every local.hyprland.shell.caffyne.bars entry must contain at least one bar.";
    }
    {
      assertion = lib.all validBarEntryShape rawBarEntries;
      message = "Each Caffyne bar object entry must declare either one widget or one non-empty group.";
    }
    {
      assertion = lib.all validBarVariant allBarEntries;
      message = "A Caffyne bar widget uses a variant that its pinned implementation does not support.";
    }
    {
      assertion = lib.all validBarGroup allBarGroups;
      message = "A Caffyne bar group contains a pair of applets that upstream marks as incompatible.";
    }
    {
      assertion = builtins.length caffyneCfg.worldClocks <= 2;
      message = "Caffyne currently supports at most two world clocks.";
    }
    {
      assertion = lib.all (clock: clock != "") caffyneCfg.worldClocks;
      message = "Caffyne world-clock identifiers must not be empty.";
    }
    {
      assertion = unique caffyneCfg.worldClocks;
      message = "Caffyne world-clock identifiers must be unique.";
    }
    {
      assertion = caffyneCfg.avatar != "";
      message = "The declarative Caffyne avatar path must not be empty.";
    }
    {
      assertion = caffyneCfg.wallpaper != "";
      message = "The declarative Caffyne wallpaper path must not be empty.";
    }
    {
      assertion = unique caffyneCfg.enabledTemplates;
      message = "Caffyne template identifiers must be unique.";
    }
    {
      assertion = lib.all (templateId: templateId != "") caffyneCfg.enabledTemplates;
      message = "Caffyne template identifiers must not be empty.";
    }
    {
      assertion = unique dashAppletKeys;
      message = "Each Caffyne Dash applet may be placed only once.";
    }
    {
      assertion = lib.all (entries: unique (map (entry: entry.key) entries)) desktopCanvasLists;
      message = "Each Caffyne desktop applet may be placed only once per monitor canvas.";
    }
    {
      assertion = lib.all (monitor: builtins.match "[0-9]+" monitor != null) (
        builtins.attrNames caffyneCfg.desktopCanvas
      );
      message = "Caffyne desktop-canvas attribute names must be numeric monitor identifiers.";
    }
  ];

  # Caffyne saves all settings sections together. A newly serialized upstream
  # section would otherwise pass silently through the merge without an explicit
  # ownership decision. Fail the package build until a maintainer classifies it
  # as Nix-owned, runtime-owned, or intentionally excluded and updates both this
  # check and the durable plan under agent-context at
  # Sessions/Caffyne Migration/DECLARATIVE-CONFIG-PLAN.md.
  caffyneSchemaCheck = pkgs.writeText "check-caffyne-user-options-schema.py" ''
    import ast
    import pathlib
    import sys

    expected = [
        "user",
        "settings",
        "bars",
        "timeouts",
        "theme",
        "launcher",
        "dock",
        "world_clocks",
        "wallpaper",
        "templates",
        "desktop_applets",
        "desktop_canvas",
    ]

    source_path = pathlib.Path(sys.argv[1])
    tree = ast.parse(source_path.read_text(), filename=str(source_path))
    user_options_class = next(
        node
        for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "UserOptions"
    )
    save_method = next(
        node
        for node in user_options_class.body
        if isinstance(node, ast.FunctionDef) and node.name == "save"
    )
    sections = None
    for node in ast.walk(save_method):
        if not isinstance(node, ast.DictComp) or not node.generators:
            continue
        iterator = node.generators[0].iter
        if isinstance(iterator, (ast.Tuple, ast.List)):
            sections = [
                item.value
                for item in iterator.elts
                if isinstance(item, ast.Constant) and isinstance(item.value, str)
            ]
            break

    if sections != expected:
        raise SystemExit(
            "Caffyne UserOptions.save() schema changed; expected "
            f"{expected!r}, found {sections!r}. Reclassify every section in "
            "modules/home-manager/hyprland/caffyne.nix before updating the pin."
        )
  '';

  upstreamCaffynePackage = inputs.caffyne.packages.${system}.default;
  caffynePackage = upstreamCaffynePackage.overrideAttrs (old: {
    # Patch order is part of the integration contract. Later patches assume the
    # launcher and native lock/idle paths have already been removed and the
    # runtime services have already been redirected to this profile's owners.
    patches = (old.patches or [ ]) ++ [
      # Make Vicinae the only launcher exposed by the shell.
      ./caffyne-vicinae-only.patch
      # Integrate logout, Wi-Fi, wallpaper, and service lifecycle behavior.
      ./caffyne-runtime-integration.patch
      # Remove Caffyne's native PAM/idle path in favor of hyprlock/hypridle.
      ./caffyne-hypridle-hyprlock.patch
      # Apply externally reconciled durable theme settings during startup.
      ./caffyne-declarative-config.patch
    ];

    # lockscreen.py and services/idle.py are dead code: nothing in the
    # patched tree imports either (verified). But Fabric registers an
    # org.Fabric.fabric.Execute D-Bus method that is exec(source, ...)
    # against main.py's live namespace, callable by anything on the user's
    # session bus, and this profile's own keybind wrapper (caffyneAction,
    # defined below) depends on that same method existing. As long
    # as the files are present on disk, a caller on that bus could still do
    # `Execute("import lockscreen; lockscreen.lock()")` and reach the native
    # PAM lock path documented in CAFFYNE-NATIVE-AUTH-ISSUES.md -- not a
    # privilege escalation (such a caller already runs as the user), but a
    # foot-gun worth removing outright rather than leaving merely
    # unreferenced. Deleting the files makes `import lockscreen` fail, so
    # the native auth path is actually gone, not just dead code.
    postPatch = (old.postPatch or "") + ''
      ${pkgs.python3}/bin/python ${caffyneSchemaCheck} user_options.py
      rm -f lockscreen.py services/idle.py
    '';
  });
  caffyneSource = inputs.caffyne;
  caffyneConfigRoot = "${config.xdg.configHome}/caffyne-shell";
  caffyneCacheRoot = "${config.xdg.cacheHome}/caffyne-shell";

  borderCssByPreset = {
    sharp = ''
      @define radius-s 0px;
      @define radius-m 0px;
      @define radius-l 0px;
      @define radius-xl 0px;
    '';
    medium = ''
      @define radius-s 4px;
      @define radius-m 10px;
      @define radius-l 16px;
      @define radius-xl 28px;
    '';
    round = ''
      @define radius-s 12px;
      @define radius-m 18px;
      @define radius-l 24px;
      @define radius-xl 36px;
    '';
  };
  fontCssByPreset = {
    none = ''
      @define mixed-mono unset;
      @define always-mono unset;
    '';
    mixed = ''
      @define mixed-mono monospace;
      @define always-mono unset;
    '';
    all = ''
      @define mixed-mono monospace;
      @define always-mono monospace;
    '';
  };
  caffyneBorderCss =
    pkgs.writeText "caffyne-borders.css"
      borderCssByPreset.${caffyneCfg.theme.border};
  caffyneFontCss =
    pkgs.writeText "caffyne-fonts.css"
      fontCssByPreset.${caffyneCfg.theme.monospaceFont};

  # Fabric exposes the same Execute method used by fabric-cli over D-Bus. Keep
  # the local wrapper intentionally narrow so Hyprland keybindings can invoke
  # only the Caffyne actions owned by this profile.
  caffyneAction = pkgs.writeShellApplication {
    name = "hypr-shell-caffyne-action";
    runtimeInputs = [
      pkgs.glib
      pkgs.systemd
    ];
    text = ''
      action="''${1:-}"

      case "$action" in
        settings)
          source="bar_manager.toggle('Settings')"
          ;;
        wifi)
          source="bar_manager.toggle('Wifi')"
          ;;
        bluetooth)
          source="bar_manager.toggle('Bluetooth')"
          ;;
        session)
          source="bar_manager.toggle('Session')"
          ;;
        wallpapers)
          source="bar_manager.toggle('Wallpapers')"
          ;;
        notifications)
          source="bar_manager.toggle('Notifications')"
          ;;
        *)
          echo "usage: hypr-shell-caffyne-action {settings|wifi|bluetooth|session|wallpapers|notifications}" >&2
          exit 64
          ;;
      esac

      exec gdbus call \
        --session \
        --dest org.Fabric.fabric.caffyne-shell \
        --object-path /org/Fabric/fabric \
        --method org.Fabric.fabric.Execute \
        "$source"
    '';
  };

  mutableStyleFiles = [
    "borders.css"
    "colors.css"
    "fonts.css"
  ];
  styleDirectory = builtins.readDir "${caffyneSource}/style";
  staticStyleFiles = lib.filter (
    name: styleDirectory.${name} == "regular" && !(builtins.elem name mutableStyleFiles)
  ) (builtins.attrNames styleDirectory);
  staticStyleConfig = builtins.listToAttrs (
    map (name: {
      name = "caffyne-shell/style/${name}";
      value.source = "${caffyneSource}/style/${name}";
    }) staticStyleFiles
  );

  # The upstream Nix wrapper currently includes swww even though Caffyne's
  # wallpaper service calls awww. Supply every externally executed command
  # through the service environment without patching or forking Caffyne.
  #
  # No wlsunset here: night_mode.py no longer spawns it directly. Night light
  # is now systemd-owned services.hyprsunset (see default.nix), and Caffyne's
  # night-mode tile only shells out to `systemctl --user start/stop
  # hyprsunset.service`, the same "Caffyne owns UI, systemd owns lifecycle"
  # split already used for the Caffeine tile. pkgs.systemd below already
  # covers that.
  caffyneRuntimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.bluez
    pkgs.brightnessctl
    pkgs.coreutils
    pkgs.ddcutil
    pkgs.git
    pkgs.glib
    pkgs.hyprland
    pkgs.matugen
    pkgs.networkmanager
    pkgs.pipewire
    pkgs.playerctl
    pkgs.procps
    pkgs.pulseaudio
    pkgs.systemd
    pkgs.util-linux
    pkgs.wf-recorder
    pkgs.wireplumber
    unstable.awww
    cfg.commands.caffeineScript
  ];
in
{
  # Declare the option surface unconditionally so another module may configure
  # Caffyne before selecting the backend. All packages, files, activation work,
  # and services remain gated by `caffyneEnabled` below.
  options.local.hyprland.shell.caffyne = {
    avatar = lib.mkOption {
      type = types.str;
      default = "/var/lib/AccountsService/icons/${config.home.username}";
      description = ''
        Avatar path stored in Caffyne's durable user configuration.
      '';
    };

    bars = lib.mkOption {
      type = types.listOf monitorBarsType;
      default = [
        {
          monitor = 0;
          alignment = "top";
          floating = true;
          bars = [
            {
              alignment = "top";
              floating = true;
              floatingApplets = true;
              roundedEdges = true;
              minimumWidth = false;
              autoHide = false;
              # Keep live layout editing out of the default bar because Nix
              # owns the durable layout. `Dash` remains a valid widget for an
              # explicit opt-in while this default stays fully declarative.
              left = [
                {
                  widget = "Processes";
                  variant = "scale";
                }
                "Weather"
                "Media"
              ];
              center = [
                "Calendar"
                {
                  widget = "Clock";
                  variant = "icon+label";
                }
              ];
              right = [
                "Tray"
                {
                  widget = "Settings";
                  variant = "single";
                }
                "Notifications"
              ];
            }
          ];
        }
      ];
      description = ''
        Declarative Caffyne bar layouts. Caffyne may edit these values while
        running, but Home Manager reasserts them on the next activation. Dock
        is intentionally unavailable because this profile does not put
        applications in the bar.
      '';
    };

    theme = {
      light = lib.mkOption {
        type = types.str;
        default = "catppuccin-latte";
        description = "Caffyne light-theme identifier.";
      };
      dark = lib.mkOption {
        type = types.str;
        default = "catppuccin-mocha";
        description = "Caffyne dark-theme identifier.";
      };
      activeAccent = lib.mkOption {
        type = types.str;
        default = "accent4";
        description = "Active Caffyne theme accent.";
      };
      darkMode = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether Caffyne starts with its dark theme active.";
      };
      scheme = lib.mkOption {
        type = types.str;
        default = "scheme-tonal-spot";
        description = "Matugen color-scheme type used by Caffyne.";
      };
      opacity = lib.mkOption {
        type = types.numbers.between 0.2 1.0;
        default = 1.0;
        description = "Caffyne surface opacity.";
      };
      blur = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether Caffyne enables compositor blur on its surfaces.";
      };
      border = lib.mkOption {
        type = types.enum [
          "sharp"
          "medium"
          "round"
        ];
        default = "medium";
        description = "Caffyne border-radius preset.";
      };
      monospaceFont = lib.mkOption {
        type = types.enum [
          "none"
          "mixed"
          "all"
        ];
        default = "none";
        description = "Caffyne monospace-font preset.";
      };
    };

    worldClocks = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "Europe/London"
        "Europe/Paris"
      ];
      description = "Up to two IANA time-zone identifiers shown by Caffyne.";
    };

    wallpaper = lib.mkOption {
      type = types.str;
      default = "${caffyneConfigRoot}/wallpapers/wall14.jpg";
      description = ''
        Stable wallpaper path stored by Caffyne. Prefer a Home Manager path
        over a versioned Nix store path.
      '';
    };

    enabledTemplates = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Caffyne template identifiers enabled for Matugen. This selects
        templates but does not install their source directories or run their
        optional imperative enable and disable scripts.
      '';
    };

    dashApplets = lib.mkOption {
      type = types.listOf dashAppletType;
      default = [ ];
      description = "Declarative applet placement in Caffyne's Dash launcher page.";
    };

    desktopCanvas = lib.mkOption {
      type = types.attrsOf (types.listOf desktopCanvasEntryType);
      default = { };
      description = ''
        Declarative desktop applet placements keyed by numeric monitor
        identifier. The single-display default has no desktop applets.
      '';
    };
  };

  config = lib.mkIf caffyneEnabled {
    assertions = caffyneAssertions;

    local.hyprland.commands.caffyneAction = caffyneAction;

    home.packages = [
      caffyneAction
      caffynePackage
      pkgs.matugen
    ];

    # Caffyne writes colors, borders and font choices at runtime. Keep those
    # three files mutable while managing the rest of upstream's style tree as
    # versioned links. Themes and bundled wallpapers are read-only inputs.
    xdg.configFile = staticStyleConfig // {
      "caffyne-shell/themes".source = "${caffyneSource}/themes";
      "caffyne-shell/wallpapers".source = "${caffyneSource}/wallpapers";
    };

    home.activation.seedCaffyneConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_root=${lib.escapeShellArg caffyneConfigRoot}
      config_file="$config_root/config/config.json"

      ${pkgs.coreutils}/bin/mkdir -p \
        "$config_root/config" \
        "$config_root/plugins" \
        "$config_root/style" \
        "$config_root/templates"

      # Caffyne atomically replaces this file whenever any UI setting is saved,
      # including runtime-owned Do Not Disturb state. Keep it writable and
      # reconcile only the durable sections Nix owns. A Home Manager store
      # symlink would make every Caffyne save fail.
      if [ -L "$config_file" ]; then
        echo "error: $config_file must be a writable regular file, not a symlink" >&2
        exit 1
      fi

      runtime_config="$config_file.hm-runtime"
      durable_config="$config_file.hm-durable"
      current_canonical="$config_file.hm-current-canonical"
      durable_canonical="$config_file.hm-durable-canonical"

      # All temporary files live beside config.json so the final rename stays
      # on one filesystem. Caffyne and Home Manager then observe either the old
      # complete file or the new complete file, never a partially written file.

      ${pkgs.coreutils}/bin/rm -f \
        "$runtime_config" \
        "$durable_config" \
        "$current_canonical" \
        "$durable_canonical"

      if [ -e "$config_file" ]; then
        if ! ${pkgs.jq}/bin/jq -e 'type == "object"' "$config_file" >/dev/null; then
          echo "error: refusing to overwrite malformed Caffyne configuration at $config_file" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/cp -- "$config_file" "$runtime_config"
      else
        ${pkgs.jq}/bin/jq -n '{}' > "$runtime_config"
      fi

      # `*` recursively merges objects while replacing arrays. The generated
      # durable values win; runtime-only and unknown top-level sections remain.
      if ! ${pkgs.jq}/bin/jq \
        --slurpfile durable ${caffyneDurableConfigFile} \
        '. * $durable[0]' \
        "$runtime_config" > "$durable_config"; then
        ${pkgs.coreutils}/bin/rm -f \
          "$runtime_config" \
          "$durable_config" \
          "$current_canonical" \
          "$durable_canonical"
        echo "error: could not reconcile declarative Caffyne configuration" >&2
        exit 1
      fi

      if ! ${pkgs.jq}/bin/jq -S -c . "$durable_config" > "$durable_canonical"; then
        ${pkgs.coreutils}/bin/rm -f \
          "$runtime_config" \
          "$durable_config" \
          "$current_canonical" \
          "$durable_canonical"
        echo "error: generated Caffyne configuration is not valid JSON" >&2
        exit 1
      fi

      config_changed=1
      # Compare canonical JSON rather than formatting. This avoids rewriting and
      # restarting Caffyne when only indentation or object-key order differs.
      if [ -e "$config_file" ] \
        && ${pkgs.jq}/bin/jq -S -c . "$config_file" > "$current_canonical" \
        && ${pkgs.diffutils}/bin/cmp -s "$current_canonical" "$durable_canonical"; then
        config_changed=0
      fi

      if [ "$config_changed" -eq 1 ]; then
        ${pkgs.coreutils}/bin/chmod 0600 "$durable_config"
        ${pkgs.coreutils}/bin/mv -f -- "$durable_config" "$config_file"
      fi
      ${pkgs.coreutils}/bin/chmod 0600 "$config_file"

      ${pkgs.coreutils}/bin/rm -f \
        "$runtime_config" \
        "$durable_config" \
        "$current_canonical" \
        "$durable_canonical"

      # Border and font CSS are derived from durable Nix options but stay real
      # writable files so Caffyne's UI writer continues to work between Home
      # Manager activations. colors.css is generated by Matugen after startup;
      # seed it only when absent so StyleService always has a valid input.
      ${pkgs.coreutils}/bin/install -m 0644 ${caffyneBorderCss} "$config_root/style/borders.css"
      ${pkgs.coreutils}/bin/install -m 0644 ${caffyneFontCss} "$config_root/style/fonts.css"
      if [ ! -e "$config_root/style/colors.css" ]; then
        ${pkgs.coreutils}/bin/install -m 0644 ${caffyneSource}/style/colors.css "$config_root/style/colors.css"
      fi

      # reloadSystemd runs earlier in Home Manager's activation DAG. Restart
      # an already-running shell only after its writable config and generated
      # style inputs are ready. try-restart leaves an inactive Hyprland session
      # alone; its next normal start will read the reconciled file.
      if [ "$config_changed" -eq 1 ]; then
        # Caffyne rebuilds this derived Matugen file only when it is absent.
        # Invalidate it so a declarative templates.enabled change is reflected
        # after the restart below instead of continuing to use stale entries.
        ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg "${caffyneCacheRoot}/matugen-templates.toml"}
        ${pkgs.systemd}/bin/systemctl --user try-restart caffyne-shell.service || true
      fi
    '';

    systemd.user.services.caffyne-shell = {
      Unit = {
        Description = "Caffyne desktop shell";
        After = [
          hyprlandSessionTarget
          "caffyne-awww.service"
        ];
        # Order after awww but do not hard-require it: awww's own
        # Restart=on-failure/RestartSec=1 can hit systemd's default
        # DefaultStartLimitBurst=5 within DefaultStartLimitIntervalSec=10s (five
        # failures in ~5s), which lands caffyne-awww in "failed". A Requires=
        # here would then stop or refuse to (re)start the whole shell over a
        # wallpaper-daemon hiccup. The runtime patch already makes Caffyne
        # degrade gracefully (skips the initial wallpaper apply) when awww
        # isn't ready, so Wants= + After= gives the same startup ordering
        # without coupling the shell's availability to awww's.
        Wants = [ "caffyne-awww.service" ];
        PartOf = [ hyprlandSessionTarget ];
        # Starting Caffyne also retires processes left behind by the previous
        # Quickshell generation. Home Manager defaults
        # systemd.user.startServices to true, which uses sd-switch to stop
        # units that disappear from the generation during a backend switch, so
        # this Conflicts= list is not what makes that happen. Keep it anyway as
        # defence-in-depth against a leftover running instance if that
        # mechanism is ever disabled or misses a unit.
        Conflicts = [
          "hypr-shell-awww.service"
          "hypr-shell-quickshell.service"
          "hypr-shell-waypaper-restore.service"
        ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = lib.getExe caffynePackage;
        Environment = [
          "PATH=${caffyneRuntimePath}"
          "PYTHONUNBUFFERED=1"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # Keep awww under systemd rather than as a Caffyne child. Caffyne waits for
    # `awww query` before its first apply; systemd restarts the daemon if it dies
    # and stops it when the Hyprland target is stopped or the backend changes.
    systemd.user.services.caffyne-awww = {
      Unit = {
        Description = "Caffyne awww wallpaper daemon";
        # Match caffyne-shell's ordering: without this, sd-switch/systemd is
        # free to start awww before the Hyprland session target is up, which
        # is pointless (there is no compositor yet to hand a wallpaper to).
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
        Conflicts = [ "hypr-shell-awww.service" ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = "${unstable.awww}/bin/awww-daemon";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
