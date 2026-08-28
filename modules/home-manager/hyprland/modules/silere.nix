{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# silere-shell is the Quickshell/QML bar for this Hyprland profile. It is the
# only shell here -- there is no backend option to choose between, unlike the
# old Caffyne/Quickshell split this profile tore down. Everything below gates
# on local.hyprland.enable like the rest of the profile.
#
# This module packages the shell from the user's fork (input `silere-shell`,
# custom-branch) and declares its first-generation defaults through
# `options.local.hyprland.silere.*` below, which get rendered into the
# package's config/GeneratedDefaults.qml at build time. The shell's own
# Settings UI can still override any of these per-key at runtime.
let
  cfg = config.local.hyprland;
  sc = cfg.silere;
  hyprlandSessionTarget = config.wayland.systemd.target;

  # QML-safe literal for a Nix bool/int/real/string: JSON and QML/JS literal
  # syntax agree on all four (true/false, bare numbers, double-quoted
  # strings with the same escaping rules), so this is the whole job.
  qml = builtins.toJSON;

  # Rendered in the same shape/comment style as the fork's checked-in
  # config/GeneratedDefaults.qml, with every value substituted from
  # local.hyprland.silere.*. installPhase below overwrites the fork's copy
  # with this one. Per-key Settings-UI overrides at runtime still win --
  # ShellSettings.qml only reads GeneratedDefaults as its own initializers.
  silereGeneratedDefaultsQml = pkgs.writeText "GeneratedDefaults.qml" ''
    pragma Singleton

    // Substitution point for the Nix packaging: rendered by
    // modules/home-manager/hyprland/silere.nix from local.hyprland.silere.*
    // and written over the fork's checked-in copy at build time. Edit the
    // Nix options, not this file -- it is regenerated on every build.

    import QtQuick
    import Quickshell

    Singleton {
        id: root

        readonly property bool   barFloating:         ${qml sc.barFloating}
        readonly property string barPosition:         ${qml sc.barPosition}
        readonly property int    barGap:              ${qml sc.barGap}
        readonly property int    barRadius:           ${qml sc.barRadius}
        readonly property real   barWidth:            ${qml sc.barWidth}
        readonly property bool   barFitGaps:          ${qml sc.barFitGaps}
        readonly property int    barHeight:           ${qml sc.barHeight}
        readonly property int    barIconSize:         ${qml sc.barIconSize}
        readonly property bool   barShadow:           ${qml sc.barShadow}
        readonly property bool   barBorderVisible:    ${qml sc.barBorderVisible}
        readonly property bool   barShowMedia:        ${qml sc.barShowMedia}
        readonly property bool   barShowClock:        ${qml sc.barShowClock}
        readonly property bool   barShowNetwork:      ${qml sc.barShowNetwork}
        readonly property bool   barShowBluetooth:    ${qml sc.barShowBluetooth}
        readonly property bool   barShowBattery:      ${qml sc.barShowBattery}
        readonly property bool   barShowVolume:       ${qml sc.barShowVolume}
        readonly property bool   barShowBrightness:   ${qml sc.barShowBrightness}
        readonly property string barWidgetOrderLeft:  ${qml sc.barWidgetOrderLeft}
        readonly property string barWidgetOrderCenter: ${qml sc.barWidgetOrderCenter}
        readonly property string barWidgetOrderRight: ${qml sc.barWidgetOrderRight}
        readonly property bool   barWidgetOrderLocked: ${qml sc.barWidgetOrderLocked}
        readonly property string caffeineUnit:        ${qml sc.caffeineUnit}
        readonly property string caffeinePresets:     ${qml sc.caffeinePresets}
        readonly property string dndPresets:          ${qml sc.dndPresets}
        readonly property string wifiEditCommand:     ${qml sc.wifiEditCommand}
        readonly property string btEditCommand:       ${qml sc.btEditCommand}
        readonly property string systemMonitorCommand: ${qml sc.systemMonitorCommand}
        readonly property bool   barShowCaffeine:     ${qml sc.barShowCaffeine}
        readonly property bool   trayWidget:          ${qml sc.trayWidget}
        readonly property bool   neutralTheme:        ${qml sc.neutralTheme}
        readonly property string baseTone:            ${qml sc.baseTone}
        readonly property string matugenAccentRole:   ${qml sc.matugenAccentRole}
        readonly property string matugenDepth:        ${qml sc.matugenDepth}
        readonly property string fontFamily:          ${qml sc.fontFamily}
        readonly property real   uiScale:             ${qml sc.uiScale}
        readonly property bool   clock12h:            ${qml sc.clock12h}
        readonly property bool   showSeconds:         ${qml sc.showSeconds}
        readonly property bool   osdEnabled:          ${qml sc.osdEnabled}
        readonly property int    osdTimeout:          ${qml sc.osdTimeout}
        readonly property bool   glassSurfaces:       ${qml sc.glassSurfaces}
        readonly property real   glassOpacity:        ${qml sc.glassOpacity}
        readonly property real   barOpacity:          ${qml sc.barOpacity}
        readonly property bool   popupMatchBarOpacity: ${qml sc.popupMatchBarOpacity}
        readonly property bool   wsDynamic:           ${qml sc.wsDynamic}
        readonly property int    tempHotThreshold:    ${qml sc.tempHotThreshold}
        readonly property int    cpuHotPercent:       ${qml sc.cpuHotPercent}
        readonly property int    memHotPercent:       ${qml sc.memHotPercent}
        readonly property string recordingStateFile:  ${qml sc.recordingStateFile}
        readonly property string recordingStopCommand: ${qml sc.recordingStopCommand}
        readonly property string keybindsFile:        ${qml sc.keybindsFile}
        readonly property string wallpaperCommand:     ${qml sc.wallpaperCommand}
        readonly property string wallpapersDir:        ${qml sc.wallpapersDir}
    }
  '';

  # Plain copy of the same file set upstream's packaging/aur/PKGBUILD
  # installs (shell.qml, config, modules, services, assets, matugen, scripts
  # -- see that PKGBUILD's package() step). No build step, no patching beyond the
  # GeneratedDefaults.qml substitution below: this is a derivation instead
  # of a direct `inputs.silere-shell` source reference only because that
  # substitution needs an install phase to hook into.
  silereShellSrc = pkgs.stdenvNoCC.mkDerivation {
    pname = "silere-shell";
    version = inputs.silere-shell.shortRev or "unknown";
    src = inputs.silere-shell;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      dest="$out/share/silere-shell"
      install -dm755 "$dest"
      cp -a shell.qml config modules services assets matugen scripts "$dest/"

      # Overwrite the fork's checked-in GeneratedDefaults.qml with the
      # Nix-rendered one. cp -a above carried the original over read-only
      # from the Nix store (mode 444); delete-then-install sidesteps that
      # instead of chmod'ing the copy.
      rm -f "$dest/config/GeneratedDefaults.qml"
      install -m644 ${silereGeneratedDefaultsQml} "$dest/config/GeneratedDefaults.qml"

      runHook postInstall
    '';
  };

  # Tools the shell shells out to by bare name, found by:
  #   grep -rhoE 'command\s*=\s*\[[^]]*\]|exec\(\[[^]]*' services modules
  # run against the silere-shell checkout, then following every
  # Quickshell.execDetached(...) call site it didn't catch (Compositor.qml,
  # ConfigStore.qml, HyprDispatch.qml, SystemTools.qml) and the bash -c
  # script bodies those processes spawn in turn (cat, awk, busctl, ...).
  # services/SystemTools.qml's optional-tool probe list is the authoritative
  # superset of everything the stock shell may ever reach for.
  #
  # Almost every Process/execDetached call spawns "bash" (often "bash", "-c",
  # ...) as the literal command name, so bash has to be resolvable too, not
  # just the coreutils it then calls out to.
  #
  # Re-checked against the custom-branch rev this module now pins (grep
  # command\s*=\s*\[...\]|execDetached\(\[...\]|exec\(\[...\] across
  # services/modules again): NightLight.qml no longer spawns or supervises
  # hyprsunset itself -- a Nix-managed hyprsunset.service systemd unit owns
  # the daemon now, and NightLight.qml only starts/stops that unit via
  # "systemctl" and nudges it via "hyprctl hyprsunset temperature" IPC. That
  # dropped pgrep/pkill, so procps came out of this list.
  silereShellPath =
    lib.makeBinPath [
      pkgs.bash
      pkgs.brightnessctl
      pkgs.coreutils
      pkgs.inotify-tools # inotifywait: Screenshot.qml's underline-glow watcher
      pkgs.libnotify # notify-send
      pkgs.systemd # systemctl, loginctl, busctl
      # hyprsunset itself is never spawned or killed from here anymore (see
      # above), but SystemTools.qml's optional-tool probe still shells out to
      # `command -v hyprsunset`, and NightLight.qml gates its whole toggle UI
      # on that probe's result (SystemTools.hasHyprsunset) -- so the binary
      # still has to resolve on this unit's PATH even though nothing here
      # runs it directly.
      pkgs.hyprsunset
    ]
    # hyprctl is deliberately left out of the explicit list above: pkgs.hyprland
    # would drag a second copy of the compositor into the closure just to get
    # one binary, and this profile already installs Hyprland at the NixOS
    # level (programs.hyprland.enable in modules/nixos/hyprland.nix), which
    # lands hyprctl in /run/current-system/sw/bin -- the NixOS user-manager's
    # default PATH. Environment= below fully replaces this unit's PATH rather
    # than extending it, so that directory has to be appended explicitly to
    # keep hyprctl reachable.
    + ":/run/current-system/sw/bin"
    # The shell also launches user-profile apps (wifiEditCommand's kitty +
    # wifitui, both Home Manager packages) and probes their availability on
    # this same PATH before showing the launch row -- without the per-user
    # profile bin the probe fails and the row silently hides.
    + ":${config.home.profileDirectory}/bin";
in
{
  # Nix-owned defaults rendered into GeneratedDefaults.qml (see
  # silereGeneratedDefaultsQml above). Names/types mirror the fork's
  # services/ShellSettings.qml `_schema` table exactly -- that table clamps
  # or rejects out-of-bounds values silently at runtime, so the bounded
  # option types below are load-bearing, not decoration. These are
  # first-generation defaults only: the shell's own Settings UI can still
  # override any of them per-key at runtime (settings.json wins over
  # GeneratedDefaults from then on).
  options.local.hyprland.silere = {
    # -- Bar surface & geometry -------------------------------------------
    barFloating = lib.mkOption {
      type = lib.types.bool;
      default = true; # design-locked
      description = "Whether the bar floats clear of the screen edge instead of docking flush to it.";
    };

    barPosition = lib.mkOption {
      type = lib.types.enum [
        "top"
        "bottom"
      ];
      default = "top"; # design-locked
      description = "Which screen edge the bar docks to.";
    };

    barGap = lib.mkOption {
      type = lib.types.ints.between 0 24;
      default = 4;
      description = "Gap in pixels between the floating bar and the screen edge.";
    };

    barRadius = lib.mkOption {
      type = lib.types.ints.between 0 28;
      # design-locked at 9 after live comparison: at 14 the radius reaches the
      # surface-height/2 clamp in Bar.qml and the end caps render as a full
      # pill; 9 keeps the capsule-free rounded-rectangle look this rice wants.
      default = 9;
      description = "Corner radius of the bar surface, in pixels.";
    };

    barWidth = lib.mkOption {
      type = lib.types.numbers.between 0.5 1.0;
      default = 0.90;
      description = "Bar width as a fraction of the screen width.";
    };

    barFitGaps = lib.mkOption {
      type = lib.types.bool;
      # Aligns the floating bar's edges with tiled windows: the shell asks
      # hyprctl for general:gaps_out at runtime and uses it as the side
      # margins, so retuning gaps in compositor.nix needs no change here.
      # When on, barWidth above is inert (it remains the fallback if the
      # gap query fails, e.g. under a non-Hyprland compositor).
      default = true;
      description = "Fit the floating bar to the compositor's window gaps instead of barWidth.";
    };

    barHeight = lib.mkOption {
      type = lib.types.ints.between 24 60;
      default = 36;
      description = "Bar height in pixels.";
    };

    # bounds mirror the fork's _schema clamp for barIconSize; the loader
    # clamps silently, so a value outside them would lie about itself
    barIconSize = lib.mkOption {
      type = lib.types.ints.between 10 20;
      default = 12;
      description = "Bar widget glyph size in pixels.";
    };

    barShadow = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the bar casts a drop shadow.";
    };

    barBorderVisible = lib.mkOption {
      type = lib.types.bool;
      default = false; # design-locked
      description = "Whether the bar draws a static border/underline.";
    };

    # -- Bar widgets --------------------------------------------------------
    # No barShowWorkspaces: upstream removed the setting (the workspaces pill
    # is the only way into the menu, so it can no longer be hidden).
    barShowMedia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the now-playing media widget on the bar.";
    };

    barShowClock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the clock widget on the bar.";
    };

    barShowNetwork = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the network status widget on the bar.";
    };

    barShowBluetooth = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the bluetooth status widget on the bar.";
    };

    barShowBattery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the battery widget on the bar.";
    };

    barShowVolume = lib.mkOption {
      type = lib.types.bool;
      default = false;
      # The approved bar layout has no inline volume widget: hardware keys
      # (keybindings.nix) plus the OSD already cover volume, and the
      # widget would just duplicate that.
      description = "Show an inline volume widget on the bar. Off by design -- see the comment on this option in silere.nix.";
    };

    barShowBrightness = lib.mkOption {
      type = lib.types.bool;
      default = false;
      # Same reasoning as barShowVolume: hardware keys + OSD cover it.
      description = "Show an inline brightness widget on the bar. Off by design -- see the comment on this option in silere.nix.";
    };

    # The three zone-order strings are comma-separated lists of the fork's
    # barWidgetKeys (services/ShellSettings.qml). The runtime layout
    # normalizer is forgiving -- unknown keys are dropped and missing valid
    # keys are appended to their default zone -- and the Settings UI's drag
    # editor still owns per-user rearrangement at runtime. The type regex
    # mirrors the fork's own _schema validation for these keys.
    barWidgetOrderLeft = lib.mkOption {
      type = lib.types.strMatching "^[a-zA-Z]*(,[a-zA-Z]+)*$";
      # vitals rides just after the workspaces by request. Its meta group
      # ("power") differs from both neighbors' groups, so the default
      # groups-mode separators render its transient chips as their own
      # cluster with no extra mechanism -- and appearing here, they can
      # never shuffle the steady right-zone cluster at all.
      default = "workspaces,vitals,media";
      description = "Bar widgets in the left zone, comma-separated in order.";
    };

    barWidgetOrderCenter = lib.mkOption {
      type = lib.types.strMatching "^[a-zA-Z]*(,[a-zA-Z]+)*$";
      # A centered clock was tried live and rolled back the same evening --
      # the empty center matches the fork's own default. The option stays so
      # the layout remains declarable without another contract change.
      default = "";
      description = "Bar widgets in the center zone, comma-separated in order.";
    };

    barWidgetOrderRight = lib.mkOption {
      type = lib.types.strMatching "^[a-zA-Z]*(,[a-zA-Z]+)*$";
      # caffeine leads the connectivity cluster (left of wifi) by request --
      # it shares the cluster's meta group, so no divider splits it off.
      # dnd rides just after it: the two self-set session modes read as one
      # run at the cluster's head, and like recording the pill only exists
      # while the mode is on, so it costs nothing the rest of the time.
      # airplane closes the zone to the right of the clock, by request --
      # the tail spot the normalizer's auto-append gave it, kept deliberate
      # here; it too exists only while the mode is on.
      # traypopup sits ahead of both: the collapsed tray pill only exists
      # while SNI items exist, so most of the time it costs nothing. The
      # inline "tray" key stays listed but dormant (trayWidget=false).
      # recording and privacy (blinking REC dot + timer, then mic) lead the
      # zone as one capture cluster -- they share the "privacy" meta group,
      # so no divider splits them. vitals moved to the left zone (see
      # barWidgetOrderLeft).
      default = "tray,recording,privacy,traypopup,caffeine,dnd,network,bluetooth,volume,brightness,battery,clock,airplane";
      description = "Bar widgets in the right zone, comma-separated in order.";
    };

    barWidgetOrderLocked = lib.mkOption {
      type = lib.types.bool;
      # True here (the fork ships false): the three zone orders above are the
      # single source of truth, so a runtime drag can never shadow a freshly
      # declared order -- exactly the bite that prompted the lock, when a
      # persisted drag state would have hidden the vitals move. The Settings
      # page keeps its per-widget show/hide toggles; only reordering is
      # declared-only.
      default = true;
      description = "Resolve the zone orders only from these declared values, disabling the Settings drag editor.";
    };

    caffeineUnit = lib.mkOption {
      type = lib.types.strMatching "^[A-Za-z0-9_.@:-]*$";
      # The shell's Caffeine service is a thin systemd control (same pattern
      # as its NightLight/hyprsunset split): this unit's active state IS the
      # manual inhibit. The unit itself lives in session-services.nix; the
      # fork ships this key empty, which keeps the whole feature dormant on
      # non-Nix installs.
      default = "hypr-shell-caffeine.service";
      description = "systemd user unit whose active state is the manual idle inhibit.";
    };

    caffeinePresets = lib.mkOption {
      type = lib.types.strMatching "^[0-9]+(,[0-9]+)*$";
      # Minutes per entry in the shell's caffeine duration picker; 0 means
      # "until turned off" and the shell appends it if omitted. Which preset
      # is active is a runtime choice the shell persists, and Super+C honors
      # it too -- the caffeine script's toggle goes through `qs ipc` into
      # the same preset-aware code path (see scripts/hypr-shell-caffeine.sh).
      default = "15,30,60,0";
      description = "Comma-separated minutes for the caffeine timed presets (0 = until turned off).";
    };

    dndPresets = lib.mkOption {
      type = lib.types.strMatching "^[0-9]+(,[0-9]+)*$";
      # Same shape and semantics as caffeinePresets: these fill the DND row's
      # duration chips, the shell appends 0 if omitted, and the picked preset
      # is a runtime choice the shell persists. The picker's Custom slider is
      # not bound by this list -- it writes any 5-480 minute value directly.
      default = "15,30,60,0";
      description = "Comma-separated minutes for the DND timed presets (0 = until turned off).";
    };

    barShowCaffeine = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the caffeine pill on the bar while idle is inhibited.";
    };

    wifiEditCommand = lib.mkOption {
      type = lib.types.str;
      # The wifi details view's "Edit connection..." escape hatch. This is a
      # launch template, not a shell: the shell splits it on whitespace and
      # substitutes {uuid} (if present) with the active connection's uuid.
      # Here it opens wifitui -- a NetworkManager TUI -- in a floating kitty
      # window (see the wifitui-float rules in compositor.nix) instead of the
      # fork's generic nm-connection-editor default; wifitui takes no target
      # argument, so no {uuid} placeholder. The --theme points at the
      # catppuccin mocha theme.toml declared in this profile's default.nix;
      # an absolute template keeps the launch shell-free.
      default = "kitty --class wifitui-float wifitui --theme=${config.xdg.configHome}/wifitui/theme.toml";
      description = "Command template the wifi details view launches for deep connection editing.";
    };

    btEditCommand = lib.mkOption {
      type = lib.types.str;
      # Same launch-template mechanism as wifiEditCommand, driving the
      # bluetooth details view's "Open bluetooth manager..." row. bluetui is
      # a BlueZ ratatui manager; it tiles like a normal window on purpose --
      # the wifitui float covered the workspace and was reverted, so the
      # class here is targeting-only, no compositor rule attached. The
      # fork's generic default is blueman-manager.
      default = "kitty --class bluetui-tile bluetui";
      description = "Command template the bluetooth details view launches for deep device management.";
    };

    systemMonitorCommand = lib.mkOption {
      type = lib.types.str;
      # Same launch-template mechanism as wifiEditCommand, behind the vitals
      # tiles (the menu's SYSTEM strip and the bar's hot chips). {widget} is
      # the clicked tile's view in bottom's --default_widget_type vocabulary
      # (cpu/mem/temp/disk/battery), and --expanded opens that view maximized,
      # so a temps click lands on temps, a CPU click on CPU. bottom finds its
      # own config (bottom.nix; lavender selection accent to match wifitui's
      # Primary), so no --config flag rides along. Tiles like bluetui on
      # purpose; the class is targeting-only, no compositor rule attached.
      # The fork ships this key empty, which keeps the tiles inert on
      # non-Nix installs.
      default = "kitty --class btm-tile btm --default_widget_type {widget} --expanded";
      description = "Command template the vitals tiles launch, opened on the clicked tile's monitor view.";
    };

    keybindsFile = lib.mkOption {
      type = lib.types.str;
      # keybindings.nix derives this JSON from the same bindDefs list the
      # actual Hyprland binds render from, so the shell's Super+/ shortcuts
      # viewer can never drift from what the chords really do. The fork
      # ships this key empty, which keeps the viewer dormant on non-Nix
      # installs.
      default = "${config.xdg.dataHome}/silere/keybinds.json";
      description = "JSON file behind the shell's searchable keybindings viewer.";
    };

    wallpaperCommand = lib.mkOption {
      type = lib.types.str;
      # Same funneling reasoning as recordingStopCommand above, aimed at the
      # wallpaper picker instead of the recording pill: the picker's click-
      # to-apply action, its Random button, the Super+Shift+W toggle chord,
      # and a terminal `wallpaper-set` invocation all run this one command,
      # so awww's swap, matugen's retint, and the hyprlock stable-path
      # convert can never fall out of step across entry points. The shell
      # appends the chosen image's absolute path as this command's one
      # argument -- this value is a bare launch template, not a full shell
      # line. The fork ships this key empty, which keeps the whole picker
      # dormant on non-Nix installs: with no way to apply anything, its IPC
      # toggle no-ops rather than opening a dead surface.
      default = "${cfg.commands.wallpaperSetScript}/bin/wallpaper-set";
      description = "Command the shell runs to apply a wallpaper; the shell appends the image path as an argument.";
    };

    wallpapersDir = lib.mkOption {
      type = lib.types.str;
      # Mirrors default.nix's own $WALLPAPERS_DIR export exactly -- both
      # read from the one wallpapersDir expression in default.nix, exposed
      # here via commands.wallpapersDir (commands.nix) so this default can
      # never drift into a second, divergent computation of the same
      # directory. The fork ships this key empty too; unlike wallpaperCommand
      # that alone is not dormancy -- a configured command with no directory
      # still opens the picker, onto its "set wallpapersDir" guidance.
      default = cfg.commands.wallpapersDir;
      description = "Absolute directory the wallpaper picker scans for images.";
    };

    wsDynamic = lib.mkOption {
      type = lib.types.bool;
      # The widget half of GNOME-style dynamic workspaces: the bar renders
      # exactly the occupied workspaces plus one trailing empty slot instead
      # of a fixed page. The other half -- the compositor-side compactor
      # that keeps occupied workspaces contiguous -- lives in
      # compositor.nix (wsCompact); the two only make sense together.
      default = true;
      description = "Render occupied workspaces plus one trailing empty slot, GNOME-style.";
    };

    recordingStateFile = lib.mkOption {
      type = lib.types.str;
      # Presence file hypr-shell-screenrecord touches while gpu-screen-recorder runs
      # (see that script); the shell's Recording service watches it for the
      # bar's REC privacy chip. Under the runtime dir on purpose: its tmpfs
      # dies with the boot, so a crash or power loss can never leave a stale
      # file falsely showing "recording" -- the one failure mode a privacy
      # indicator must not have. The uid is spelled out because this key is
      # rendered at build time where $XDG_RUNTIME_DIR does not exist yet;
      # 1000 is NixOS's first-normal-user default and this is a single-user
      # machine. Revisit if that ever changes.
      default = "/run/user/1000/hypr-shell/recording";
      description = "Path whose existence means a screen recording is running.";
    };

    recordingStopCommand = lib.mkOption {
      type = lib.types.str;
      # The bar's recording pill runs this on click. Routed through the same
      # wrapper the record chords toggle (its stop mode SIGINTs gpu-screen-recorder)
      # so the pill, the chords, and a terminal invocation share one stop
      # path and can never disagree about notification or cleanup behavior.
      default = "${cfg.commands.screenrecordScript}/bin/hypr-shell-record stop";
      description = "Command the shell's recording pill runs to stop a running recording.";
    };

    # -- Vitals thresholds ---------------------------------------------------
    # The bar's vitals chips exist only while a metric is over its threshold
    # (with clear-at-minus-5 hysteresis fork-side), so these numbers decide
    # how loud the bar is on a stressed machine, not whether monitoring runs.
    tempHotThreshold = lib.mkOption {
      type = lib.types.ints.between 50 105;
      # Well below the fork's 90: this laptop throttles late, and the point
      # is early awareness, not shutdown protection.
      default = 65;
      description = "CPU temperature (deg C) above which the bar's temp chip appears.";
    };

    cpuHotPercent = lib.mkOption {
      type = lib.types.ints.between 30 100;
      default = 70;
      description = "CPU usage percent above which the bar's CPU chip appears.";
    };

    memHotPercent = lib.mkOption {
      type = lib.types.ints.between 30 100;
      default = 70;
      description = "Memory usage percent above which the bar's memory chip appears.";
    };

    glassSurfaces = lib.mkOption {
      type = lib.types.bool;
      # The fork's glassmorphism mode: popups and menu panes paint a
      # wallpaper-tinted translucent surface into the blur the compositor
      # puts behind every silere-* layer (see the layer_rule + blur
      # vibrancy tuning in compositor.nix -- the two halves only work
      # together). The fork ships this off so non-Nix installs, which have
      # no blur rules, don't get dim unfrosted popups.
      default = true;
      description = "Frosted-glass popup surfaces tinted by the matugen wallpaper palette.";
    };

    glassOpacity = lib.mkOption {
      type = lib.types.numbers.between 0.5 0.95;
      # Live design loop, second pass (2026-08-18): 0.70 was the first
      # landing; the user later pulled it to 0.60 for more frost. The
      # Settings UI slider (Layout -> GLASS) still overrides it at runtime
      # per-user, so a persisted slider value shadows this default.
      default = 0.60;
      description = "Alpha of glass popup surfaces (0.5-0.95); lower shows more frost.";
    };

    barOpacity = lib.mkOption {
      type = lib.types.numbers.between 0.4 1.0;
      # The bar's half of the glass look: it sits in the same silere-*
      # blur rule as the popups, so this alpha is what turns it frosted.
      # A step above glassOpacity on purpose -- the persistent surface
      # reads slightly more solid than transient popups while staying the
      # same material (0.64 over glass's 0.60, second design-loop pass).
      # Fork default is 0.88.
      default = 0.64;
      description = "Alpha of the bar's glass surface (0.4-1.0); lower shows more frost.";
    };

    popupMatchBarOpacity = lib.mkOption {
      type = lib.types.bool;
      # Upstream 0.6.1+ lets the bar-anchored popups (notifications,
      # calendar, tray, quick actions) reuse the bar's opacity. Moot while
      # glassSurfaces is on -- Theme.popup checks glass first -- so this
      # just mirrors the fork's default.
      default = false;
      description = "Bar-anchored popups follow the bar's opacity when glass mode is off.";
    };

    trayWidget = lib.mkOption {
      type = lib.types.bool;
      default = false;
      # A tray popup widget is a later design-phase item. Until it lands,
      # the tray is still reachable through the shell's own Settings UI
      # runtime toggle -- this option only controls the bar's inline icon.
      description = "Show the system tray widget on the bar. Off until the tray popup widget design lands -- see the comment on this option in silere.nix.";
    };

    # -- Theme ---------------------------------------------------------------
    neutralTheme = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use a fixed neutral accent instead of a matugen wallpaper-derived one.";
    };

    baseTone = lib.mkOption {
      type = lib.types.enum [
        "black"
        "charcoal"
        "graphite"
      ];
      default = "black";
      description = "Base surface tone the theme builds on.";
    };

    matugenAccentRole = lib.mkOption {
      type = lib.types.enum [
        "primary"
        "secondary"
        "tertiary"
      ];
      default = "primary";
      description = "Which matugen palette role drives the shell's accent color.";
    };

    matugenDepth = lib.mkOption {
      type = lib.types.enum [
        "none"
        "deep"
        "deeper"
      ];
      # Upstream default is "deeper"; the approved theme wants the "deep"
      # sunk-wallpaper-hue look instead, one step lighter.
      default = "deep";
      description = "How strongly matugen's wallpaper-derived hue sinks into the base surfaces.";
    };

    # -- Typography & scale ---------------------------------------------------
    fontFamily = lib.mkOption {
      # Mirrors the schema's control-character-free, <=128-character
      # constraint on fontFamily. Nix's POSIX-regex strMatching has no
      # \x/\u escapes to spell "no control characters" as a character
      # class directly, so this checks the length bound (the one a
      # rendered value could plausibly violate) and rejects the control
      # characters most likely to appear by accident.
      type = lib.types.addCheck lib.types.str (
        v: builtins.stringLength v <= 128 && builtins.match ".*[\n\t\r].*" v == null
      );
      # Follow the profile-wide monospace font (local.fonts.mono, Berkeley
      # Mono) rather than pinning a family here, so the bar tracks the role
      # instead of drifting when it changes. The mono role, not ui: the bar is
      # the one dense, data-like surface (clock digits, workspace glyphs)
      # where the mono face is the deliberate look. Nerd-Font icon glyphs are
      # unaffected: fontconfig's per-glyph fallback resolves them through
      # Symbols Nerd Font regardless of the text face.
      default = config.local.fonts.mono.family;
      description = "UI font family. Must be free of newlines/tabs and at most 128 characters, matching the shell's own validation.";
    };

    uiScale = lib.mkOption {
      type = lib.types.numbers.between 0.8 1.15;
      default = 1.0;
      description = "Global UI scale factor.";
    };

    # -- Clock ----------------------------------------------------------------
    clock12h = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the clock in 12-hour time instead of 24-hour.";
    };

    showSeconds = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show seconds in the clock.";
    };

    # -- OSD -------------------------------------------------------------------
    osdEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the volume/brightness on-screen display.";
    };

    osdTimeout = lib.mkOption {
      type = lib.types.ints.between 500 10000;
      default = 2000;
      description = "How long the OSD stays visible, in milliseconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    local.hyprland.commands.silereShellPackage = silereShellSrc;

    home.packages = with pkgs; [
      quickshell

      # Qt runtime support the QML shell needs to render under Wayland.
      qt6.qtwayland
      qt6.qtdeclarative
      qt6.qtsvg
      qt6.qtimageformats
      libsForQt5.qtwayland
    ];

    systemd.user.services.silere-shell = {
      Unit = {
        Description = "silere-shell Quickshell bar";
        # Without this ordering, systemd is free to start the shell before
        # Hyprland (and a Wayland display to connect to) is up, which burns
        # the unit's restart budget on early, unrecoverable failures.
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = "${lib.getExe' pkgs.quickshell "qs"} -p ${silereShellSrc}/share/silere-shell/shell.qml";
        Restart = "on-failure";
        Environment = [ "PATH=${silereShellPath}" ];
      };
    };
  };
}
