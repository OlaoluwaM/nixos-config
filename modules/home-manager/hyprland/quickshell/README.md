# Quickshell Shell

This directory contains the QML for the Hyprland desktop shell: the top bar,
popovers, notifications, tray, and OSD.

Quickshell runs `shell.qml` first. That file wires shared services, starts
small data pipes, and creates the windows. The other QML files draw the visible
parts of those windows and receive only the service objects they need.

## Files To Start With

- `shell.qml`: top-level service wiring, timers, data pipes, and windows.
- `GeneratedTheme.qml`: generated color/font tokens from Nix.
- `GeneratedCommands.qml`: generated command/script paths from Nix.
- `CommandRunner.qml`: shared command execution and refresh signaling.
- `ShellShortcuts.qml`: Hyprland global shortcut bindings exposed as QML
  actions.
- `StatusController.qml`: public status façade passed to UI modules.
- `AudioStatus.qml`, `BatteryStatus.qml`, `MediaStatus.qml`,
  `SystemStatus.qml`: private status-domain controllers used by
  `StatusController`.
- `AudioActions.qml`, `BrightnessActions.qml`, `MediaActions.qml`,
  `PowerActions.qml`, `ConnectivityActions.qml`, `CaffeineActions.qml`: domain
  APIs used by UI components. Audio/media use native Quickshell services; the
  others wrap command-backed integrations.
- `NotificationService.qml`: the notification server, history/popup models, and
  do-not-disturb state.
- `PopupController.qml`, `OsdController.qml`: small state controllers for the
  active popover and the OSD, driven from `shell.qml`.
- `Bar.qml`: top bar layout and capsule composition.
- `WorkspaceCapsule.qml`, `StatsCapsule.qml`, `MediaCapsule.qml`,
  `ClockCapsule.qml`, `NotificationCapsule.qml`, `TrayCapsule.qml`,
  `AirplaneModeCapsule.qml`, `NetworkCapsule.qml`, `BluetoothCapsule.qml`,
  `CaffeineCapsule.qml`, `QuickSettingsCapsule.qml`: top-bar capsule
  implementations.
- `Popovers.qml`: the popup window and the Loader that swaps popup panels.
- `QuickSettings.qml`, `CalendarPanel.qml`, `TrayPanel.qml`, `MediaPanel.qml`,
  `NotificationPanel.qml`: popup contents.
- `ToastNotifications.qml`: temporary notification cards.
- `NotificationCard.qml`: shared notification/toast card body.
- `ConfirmDialog.qml`: confirmation modal for destructive power actions.
- `OsdOverlay.qml`: volume, brightness, and keyboard-backlight overlay.
- `Theme.qml`: shared design system for sizes, animation durations, and color
  helpers. It reads generated color/font tokens from `GeneratedTheme.qml`.
- `Icons.qml` and `ShellIcon.qml`: SVG icon data and icon rendering.

## Shared UI Pieces

The small reusable files keep common visual patterns in one place:

- `BarCapsule.qml`: standard top-bar capsule frame.
- `WorkspaceCapsule.qml`, `StatsCapsule.qml`, `MediaCapsule.qml`,
  `ClockCapsule.qml`, `NotificationCapsule.qml`, `TrayCapsule.qml`,
  `AirplaneModeCapsule.qml`, `NetworkCapsule.qml`, `BluetoothCapsule.qml`,
  `CaffeineCapsule.qml`, `QuickSettingsCapsule.qml`: domain-specific top-bar
  capsules built on `BarCapsule` or the same geometry constants.
- `IconButton.qml`: small icon-only button.
- `ActionButton.qml`: short text action button.
- `HoverTooltip.qml`: hover label bubble.
- `StyledText.qml`: the shared text element with the shell's default font.
- `StyledSlider.qml`: quick-settings slider skin.
- `NotificationActionRow.qml`: notification action buttons.
- `NotificationCard.qml`: shared notification card shell used by toasts and
  the notification panel.
- `MarqueeText.qml`: text that scrolls only when it is too wide.

If two panels need the same button, tooltip, slider, or bar capsule styling,
prefer changing one of these components instead of copying a new local block.

## Important Rules

Every new QML file must be added to `qmldir`. This directory has a `qmldir`
manifest, so Qt does not auto-discover new files.

Home Manager copies this directory as the Quickshell config. Hand-written files
such as `Theme.qml` are copied as-is; generated files such as
`GeneratedTheme.qml` and `GeneratedCommands.qml` are overwritten by
`quickshell.nix` with generated content.

Keep command placeholders such as `@STATUS_SCRIPT@` in
`GeneratedCommands.qml` only. `quickshell.nix` replaces those placeholders
with real Nix store paths. Child components should call methods on the narrow
domain object they receive, such as `powerActions.runPowerProfileSet(...)`,
instead of embedding command strings or depending on `shell.qml`. Prefer native
Quickshell services over shell commands when Quickshell already exposes the
domain, as it does for PipeWire audio, MPRIS media, and UPower battery state.

Hyprland keybinds that target shell behavior should use the `global`
dispatcher, for example `global, quickshell:quickSettings`, and the matching
action should live in `ShellShortcuts.qml`. Avoid adding file-polling bridges
for keybinds; use Quickshell IPC only when an external command-line entry point
is genuinely needed.

## Popup Loading

`Popovers.qml` uses a `Loader` to create the active popup panel. When the popup
closes, the Loader source is cleared so the hidden panel is destroyed instead of
kept around in memory.

Qt Loader documentation:
<https://doc.qt.io/qt-6/qml-qtquick-loader.html>

## Testing

The normal path is Home Manager:

- `quickshell.nix` writes `~/.config/quickshell/hyprland/shell.qml`.
- The `hypr-shell-quickshell` user service runs
  `quickshell --config hyprland`.
- The TTY helper is only a temporary host-side test harness. The QML does not
  import it or call it.

For real layer-shell behavior before a full Home Manager switch, test from a
TTY:

```sh
./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh
```

After the test session exits, check the Quickshell log printed by the helper.
That log is the fastest way to find QML load errors, missing `qmldir` entries,
or unsubstituted placeholders.

## Future Items to Consider

- Blur & Translucencies in windows and in the topbar
- A topbar design more like [this](https://github.com/ilyamiro/nixos-configuration/blob/master/previews/screenshot1.png)
  - Particularly, grouping some of the rightmost capsules together
- Quickshell script test suite
- A Quickshell widget that displays device usage metric like AppBlock. Similar to [this](https://github.com/ilyamiro/nixos-configuration/blob/master/previews/screenshot6.png)
- Frosted glass effect
