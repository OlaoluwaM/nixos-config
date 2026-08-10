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
  # The schema check below catches serialized sections, and the widget-tables
  # check catches renamed widgets or popup applets, changed variant sets,
  # incompatible-group pairs, and desktop applet names. Still unchecked: theme
  # preset names and the desktop-canvas placement field semantics.

  # These values mirror the pinned bar implementation. Keeping them here makes
  # invalid layouts fail during Home Manager evaluation instead of at Caffyne
  # startup. Empty variant lists mean that the widget accepts no variant field.
  # The mirror is enforced: caffyneWidgetTablesCheck below re-derives these
  # tables from the patched source at build time and fails the package build
  # on any drift, so a pin update cannot silently invalidate them.
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

  # One catalogue owns every user-facing Caffyne action. It generates both the
  # allowlisted D-Bus helper and the desktop entries indexed by Vicinae, so a
  # maintainer cannot add an entry that the helper refuses to execute (or add
  # a helper action that remains undiscoverable).
  #
  # `applet` entries must match the patched APPLET_WIDGETS table exactly. The
  # build-time source check below enforces that contract. `page` entries are
  # dedicated Dash pages that Caffyne exposes through BarManager.toggle(); they
  # do not expose the general Dash, app launcher, or live layout editor.
  #
  # Bar-only widgets are deliberately absent: Workspaces and Focused have no
  # popup, Tray delegates actions to each status item, and Brightness lives in
  # Settings. Dash, Dock, and Launcher conflict with this profile's declarative
  # layout or its Vicinae-only application-launcher boundary.
  caffyneActions = {
    bluetooth = {
      key = "Bluetooth";
      name = "Bluetooth";
      icon = "bluetooth-duotone";
      comment = "Manage Bluetooth devices with Caffyne";
      categories = [ "Settings" ];
      kind = "applet";
    };
    calculator = {
      key = "Calculator";
      name = "Calculator";
      icon = "calculator-duotone";
      comment = "Open Caffyne's calculator";
      categories = [ "Utility" ];
      kind = "applet";
    };
    calendar = {
      key = "Calendar";
      name = "Calendar";
      icon = "calendar-blank-duotone";
      comment = "Open Caffyne's calendar";
      categories = [ "Office" ];
      kind = "applet";
    };
    clock = {
      key = "Clock";
      name = "Clocks and Timers";
      icon = "clock-duotone";
      comment = "Open Caffyne's clocks and timers";
      categories = [ "Utility" ];
      kind = "applet";
    };
    energy = {
      key = "Energy";
      name = "Battery and Power";
      icon = "lightning-duotone";
      comment = "Inspect battery and power information with Caffyne";
      categories = [ "System" ];
      kind = "applet";
    };
    keyboard = {
      key = "Keyboard";
      name = "Keyboard Layout";
      icon = "keyboard-duotone";
      comment = "Select a keyboard layout with Caffyne";
      categories = [ "Settings" ];
      kind = "applet";
    };
    media = {
      key = "Media";
      name = "Media";
      icon = "music-notes-duotone";
      comment = "Control media players with Caffyne";
      categories = [ "AudioVideo" ];
      kind = "applet";
    };
    notifications = {
      key = "Notifications";
      name = "Notifications";
      icon = "bell-simple-duotone";
      comment = "Open Caffyne's notification history";
      categories = [ "Utility" ];
      kind = "applet";
    };
    processes = {
      key = "Processes";
      name = "System Monitor";
      icon = "cpu-duotone";
      comment = "Inspect system activity and processes with Caffyne";
      categories = [ "System" ];
      kind = "applet";
    };
    session = {
      key = "Session";
      name = "Session Controls";
      icon = "power-duotone";
      comment = "Lock, log out, suspend, or power off from Caffyne";
      categories = [ "System" ];
      kind = "applet";
    };
    settings = {
      key = "Settings";
      name = "Quick Settings";
      icon = "sliders-horizontal-duotone";
      comment = "Open Caffyne's quick settings";
      categories = [ "Settings" ];
      kind = "applet";
    };
    themes = {
      key = "Themes";
      name = "Theme Picker";
      icon = "palette-duotone";
      comment = "Select a Caffyne theme";
      categories = [ "Settings" ];
      kind = "page";
    };
    volume = {
      key = "Volume";
      name = "Volume";
      icon = "speaker-simple-high-duotone";
      comment = "Control application and device volume with Caffyne";
      categories = [ "Settings" ];
      kind = "applet";
    };
    wallpapers = {
      key = "Wallpapers";
      name = "Wallpaper Picker";
      icon = "image-duotone";
      comment = "Select and apply a wallpaper with Caffyne";
      categories = [ "Settings" ];
      kind = "page";
    };
    weather = {
      key = "Weather";
      name = "Weather";
      icon = "cloud-sun-duotone";
      comment = "Open Caffyne's weather forecast";
      categories = [ "Utility" ];
      kind = "applet";
    };
    wifi = {
      key = "Wifi";
      name = "Wi-Fi";
      icon = "wifi-high-duotone";
      comment = "Manage Wi-Fi networks with Caffyne";
      categories = [ "Settings" ];
      kind = "applet";
    };
  };
  caffyneActionSlugs = builtins.attrNames caffyneActions;
  caffyneAppletWidgetNames = map (action: action.key) (
    builtins.filter (action: action.kind == "applet") (builtins.attrValues caffyneActions)
  );

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
        description = "Exactly two non-nested widgets shown in the group.";
      };
    };
  };
  barEntryType = types.oneOf [
    barWidgetType
    barObjectEntryType
  ];
  # The pinned Bar is horizontal-only: it hardcodes a non-vertical layout,
  # derives its layer-shell anchors from top/bottom, and its settings UI only
  # toggles between those two edges. Left and right would serialize fine but
  # produce a broken surface, so they are not offered here.
  barAlignmentType = types.enum [
    "top"
    "bottom"
  ];

  barType = types.submodule {
    options = {
      alignment = lib.mkOption {
        type = barAlignmentType;
        default = "top";
        description = "Screen edge used by this Caffyne bar.";
      };
      floating = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Whether this bar uses Caffyne's floating presentation.";
      };
      # floatingApplets and roundedEdges are serialized-but-unread in the
      # pinned revision: Caffyne writes both into every saved bar and its
      # defaults set them, but no code path consumes either field yet. They
      # stay here because they are part of the on-disk bar schema, so omitting
      # them would make Nix-generated bars diverge from UI-saved ones. Their
      # descriptions state the intended upstream meaning; neither has any
      # visible effect until a future pin starts reading them.
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
        type = barAlignmentType;
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
        # The pinned bar renders a group only when it contains exactly two
        # widgets; its drag-and-drop editor can never create another size and
        # startup silently drops any other. Require the same shape here so a
        # bad group fails evaluation instead of vanishing from the bar.
        entry.widget == null && entry.variant == null && builtins.length entry.widgets == 2
      else
        entry.type == null && entry.widget != null && entry.widgets == [ ]
    );
  validBarVariant =
    entry:
    let
      variant = barEntryVariant entry;
    in
    variant == null || builtins.elem variant barWidgetVariants.${barEntryName entry};
  # Two deliberate gaps in the group checks below, both softer invariants than
  # the pair list and not worth failing evaluation over:
  #
  # - Upstream's drag-and-drop editor only forms groups from applet-capable
  #   widgets (the ones with a popup), so a declared group containing Tray,
  #   Workspaces, Focused, Dash, or Brightness is unrepresentable in the UI.
  #   The pinned loader still renders such a group and its popup code filters
  #   the non-applet member out, so this stays a documentation note.
  # - Nothing prevents declaring the same widget twice on one monitor. The UI
  #   treats widget presence per monitor as boolean (its applet page greys out
  #   active entries), so duplicates load but leave that page mildly confused.
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
    # Wallpaper ownership is shared with hyprlock at the parent Hyprland
    # profile. Caffyne still receives the path in its native JSON schema, but
    # it is no longer the source of truth for the durable value.
    wallpaper.path = cfg.wallpaper;
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
      message = "Each Caffyne bar object entry must declare either one widget or one group of exactly two widgets.";
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
      assertion = cfg.wallpaper != "";
      message = "The declarative Hyprland wallpaper path must not be empty.";
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

  # The Nix-side widget and applet tables above, serialized for the build-time
  # drift check. excludedBarWidgets lists widgets that exist upstream but that
  # this module deliberately does not offer (see the bars option description),
  # so the check can demand an exact match instead of a subset.
  caffyneWidgetTables = pkgs.writeText "caffyne-widget-tables.json" (
    builtins.toJSON {
      inherit
        barWidgetVariants
        caffyneAppletWidgetNames
        invalidGroupPairs
        desktopAppletNames
        ;
      excludedBarWidgets = [ "Dock" ];
    }
  );

  # Companion to caffyneSchemaCheck: re-derives the bar widget names, their
  # variant sets (following class inheritance for the shared
  # BaseButton/StatButton/ProgressButton VARIANTS), the incompatible group
  # pairs, popup applet names, and desktop applet names from the *patched*
  # source, then fails the build unless they match the Nix tables exactly. Runs
  # in postPatch so it sees the tree the shell will actually run (e.g. Launcher
  # already removed by the Vicinae patch). Limitation: plugins loaded at
  # runtime via plugin_loader can still extend these tables; only the built-ins
  # are checkable statically, and only built-ins are declarable from Nix anyway.
  caffyneWidgetTablesCheck = pkgs.writeText "check-caffyne-widget-tables.py" ''
    import ast
    import json
    import pathlib
    import sys

    src = pathlib.Path(sys.argv[1])
    expected = json.loads(pathlib.Path(sys.argv[2]).read_text())

    errors = []


    def parse(path):
        return ast.parse(path.read_text(), filename=str(path))


    def assigned_value(node, name):
        # Tables are declared both bare and annotated (`X = {}` and
        # `X: dict[str, type] = {}`); accept either.
        if isinstance(node, ast.Assign):
            if any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
                return node.value
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            if node.target.id == name:
                return node.value
        return None


    bar_tree = parse(src / "bar.py")
    bar_widgets = None
    applet_widgets = None
    incompatible = None
    for node in bar_tree.body:
        value = assigned_value(node, "BAR_WIDGETS")
        if isinstance(value, ast.Dict):
            bar_widgets = {}
            for key, cls in zip(value.keys, value.values):
                if isinstance(key, ast.Constant) and isinstance(cls, ast.Name):
                    bar_widgets[key.value] = cls.id
        value = assigned_value(node, "APPLET_WIDGETS")
        if isinstance(value, ast.Dict):
            applet_widgets = {
                key.value
                for key in value.keys
                if isinstance(key, ast.Constant)
            }
        value = assigned_value(node, "INCOMPATIBLE_GROUPS")
        if isinstance(value, ast.Set):
            incompatible = set()
            for elt in value.elts:
                if (
                    isinstance(elt, ast.Call)
                    and isinstance(elt.func, ast.Name)
                    and elt.func.id == "frozenset"
                    and elt.args
                    and isinstance(elt.args[0], ast.Set)
                ):
                    incompatible.add(
                        frozenset(
                            c.value
                            for c in elt.args[0].elts
                            if isinstance(c, ast.Constant)
                        )
                    )

    if bar_widgets is None:
        raise SystemExit("could not locate BAR_WIDGETS in bar.py")
    if applet_widgets is None:
        raise SystemExit("could not locate APPLET_WIDGETS in bar.py")
    if incompatible is None:
        raise SystemExit("could not locate INCOMPATIBLE_GROUPS in bar.py")

    # class name -> declared VARIANTS (None when the class inherits them) and
    # first base class, from every widget module. VARIANTS entries may be
    # names of module-level string constants (base.py's VARIANT_*), so those
    # are resolved per file.
    class_variants = {}
    class_base = {}
    for path in sorted((src / "bar_widgets").glob("*.py")):
        tree = parse(path)
        consts = {}
        for node in tree.body:
            if (
                isinstance(node, ast.Assign)
                and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
                and isinstance(node.value, ast.Constant)
                and isinstance(node.value.value, str)
            ):
                consts[node.targets[0].id] = node.value.value
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            variants = None
            for stmt in node.body:
                value = assigned_value(stmt, "VARIANTS")
                if isinstance(value, ast.List):
                    variants = []
                    for elt in value.elts:
                        if isinstance(elt, ast.Constant):
                            variants.append(elt.value)
                        elif isinstance(elt, ast.Name) and elt.id in consts:
                            variants.append(consts[elt.id])
                        else:
                            errors.append(
                                f"unresolvable VARIANTS entry in {path.name} "
                                f"class {node.name}"
                            )
            bases = [b.id for b in node.bases if isinstance(b, ast.Name)]
            class_variants[node.name] = variants
            class_base[node.name] = bases[0] if bases else None


    def resolve_variants(class_name):
        seen = set()
        current = class_name
        while current in class_variants and current not in seen:
            seen.add(current)
            if class_variants[current] is not None:
                return class_variants[current]
            current = class_base[current]
        # Fell off into a class outside bar_widgets (Box, EventBox):
        # no VARIANTS anywhere means the widget takes no variant field.
        return []


    excluded = set(expected["excludedBarWidgets"])
    expected_variants = expected["barWidgetVariants"]

    actual_names = set(bar_widgets)
    expected_names = set(expected_variants) | excluded
    if actual_names != expected_names:
        errors.append(
            "BAR_WIDGETS drifted: new upstream widgets "
            f"{sorted(actual_names - expected_names)}, "
            "gone from upstream "
            f"{sorted(expected_names - actual_names)}"
        )

    for widget in sorted(expected_variants):
        if widget not in bar_widgets:
            continue  # covered by the name check above
        actual = resolve_variants(bar_widgets[widget])
        if set(actual) != set(expected_variants[widget]):
            errors.append(
                f"variants for {widget} drifted: pinned implementation has "
                f"{sorted(actual)}, Nix table has "
                f"{sorted(expected_variants[widget])}"
            )

    expected_pairs = {frozenset(pair) for pair in expected["invalidGroupPairs"]}
    if incompatible != expected_pairs:
        errors.append(
            "INCOMPATIBLE_GROUPS drifted: upstream "
            f"{sorted(sorted(p) for p in incompatible)}, Nix table "
            f"{sorted(sorted(p) for p in expected_pairs)}"
        )

    expected_applets = set(expected["caffyneAppletWidgetNames"])
    if applet_widgets != expected_applets:
        errors.append(
            "APPLET_WIDGETS drifted: upstream "
            f"{sorted(applet_widgets)}, desktop-entry catalogue "
            f"{sorted(expected_applets)}"
        )

    applet_tree = parse(src / "desktop_applets" / "__init__.py")
    applet_names = None
    for node in applet_tree.body:
        value = assigned_value(node, "DESKTOP_APPLET_WIDGETS")
        if isinstance(value, ast.Dict):
            applet_names = {
                k.value for k in value.keys if isinstance(k, ast.Constant)
            }
    if applet_names is None:
        raise SystemExit(
            "could not locate DESKTOP_APPLET_WIDGETS in "
            "desktop_applets/__init__.py"
        )
    if applet_names != set(expected["desktopAppletNames"]):
        errors.append(
            "desktop applets drifted: upstream "
            f"{sorted(applet_names)}, Nix table "
            f"{sorted(expected['desktopAppletNames'])}"
        )

    if errors:
        raise SystemExit(
            "Caffyne widget tables drifted from the pinned source:\n- "
            + "\n- ".join(errors)
            + "\nReconcile the tables in "
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
      ${pkgs.python3}/bin/python ${caffyneWidgetTablesCheck} . ${caffyneWidgetTables}
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

  # Upstream's entry point consists entirely of @import statements. Reproduce
  # it verbatim and append one local import so future visual changes can stay
  # in a small downstream layer instead of patching or copying upstream CSS.
  # Loading overrides last lets a selector with equal specificity win while
  # preserving upstream defaults for everything we do not explicitly change.
  caffyneStyleCss = pkgs.writeText "caffyne-style.css" ''
    ${builtins.readFile "${caffyneSource}/style/style.css"}
    @import "overrides.css";
  '';
  caffyneOverridesCss = pkgs.writeText "caffyne-overrides.css" ''
    /*
     * Declarative downstream overrides for Caffyne.
     *
     * Keep rules narrow and document why they differ from upstream. Prefer
     * typed Nix options for durable settings and bar layout; use this file for
     * presentation that Caffyne exposes only through GTK CSS. Recheck selector
     * names whenever the pinned Caffyne revision changes.
     */
  '';

  caffyneActionCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (slug: action: ''
      ${slug})
        source="bar_manager.toggle('${action.key}')"
        ;;
    '') caffyneActions
  );
  caffyneActionUsage = lib.concatStringsSep "|" caffyneActionSlugs;

  # Use Caffyne's own duotone SVGs for visual continuity in Vicinae. Absolute
  # Nix store paths are valid desktop-entry icons and keep the entries working
  # even when the active system icon theme lacks an equivalent glyph.
  caffyneDesktopEntries = lib.mapAttrs' (
    slug: action:
    lib.nameValuePair "caffyne-${slug}" {
      name = "Caffyne · ${action.name}";
      genericName = action.name;
      inherit (action) comment categories;
      exec = "${lib.getExe caffyneAction} ${slug}";
      icon = "${caffyneSource}/svgs/${action.icon}.svg";
      terminal = false;
      # The helper asks an existing Caffyne process to show a surface. It does
      # not own a conventional application window or startup notification.
      startupNotify = false;
    }
  ) caffyneActions;

  # Fabric exposes the same Execute method used by fabric-cli over D-Bus. Keep
  # the local wrapper intentionally narrow so keybindings and desktop entries
  # can invoke only the Caffyne actions declared in caffyneActions above.
  caffyneAction = pkgs.writeShellApplication {
    name = "hypr-shell-caffyne-action";
    runtimeInputs = [
      pkgs.glib
      pkgs.systemd
    ];
    text = ''
      action="''${1:-}"

      case "$action" in
        ${caffyneActionCases}
        *)
          echo "usage: hypr-shell-caffyne-action {${caffyneActionUsage}}" >&2
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

  # These files cannot be linked directly from the pinned source. The first
  # three remain writable because Caffyne updates them at runtime. style.css is
  # generated above so it can import the Nix-owned override layer last.
  nonStaticStyleFiles = [
    "borders.css"
    "colors.css"
    "fonts.css"
    "style.css"
  ];
  styleDirectory = builtins.readDir "${caffyneSource}/style";
  staticStyleFiles = lib.filter (
    name: styleDirectory.${name} == "regular" && !(builtins.elem name nonStaticStyleFiles)
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
                # Keep workspace navigation at the bar's outer edge. The dots
                # variant shows workspace state without reintroducing the app
                # icons deliberately removed from this layout.
                {
                  widget = "Workspaces";
                  variant = "dots";
                }
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

    # Vicinae indexes these like normal applications. This provides direct,
    # searchable access to each applet without putting every widget on the bar
    # or restoring Dash's imperative layout editor.
    xdg.desktopEntries = caffyneDesktopEntries;

    # Caffyne writes colors, borders and font choices at runtime. Keep those
    # three files mutable while managing the rest of upstream's style tree as
    # versioned links. style.css and overrides.css are separate Nix-owned files
    # so downstream presentation changes have an explicit, reviewable home.
    # Themes and bundled wallpapers remain read-only inputs.
    xdg.configFile = staticStyleConfig // {
      "caffyne-shell/style/style.css".source = caffyneStyleCss;
      "caffyne-shell/style/overrides.css".source = caffyneOverridesCss;
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
      # desktop_canvas.placements needs an explicit assignment on top of that:
      # it is an object keyed by monitor identifier, so the recursive merge
      # would preserve runtime placements on any monitor this profile does not
      # declare, letting canvas edits survive activation despite Nix owning
      # the whole section.
      if ! ${pkgs.jq}/bin/jq \
        --slurpfile durable ${caffyneDurableConfigFile} \
        '. * $durable[0] | .desktop_canvas.placements = $durable[0].desktop_canvas.placements' \
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
