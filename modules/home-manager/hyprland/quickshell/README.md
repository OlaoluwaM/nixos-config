# Quickshell Shell

This directory contains the QML for the Hyprland desktop shell: the top bar,
popovers, notifications, tray, and OSD.

Quickshell runs `shell.qml` first. That file wires shared services, starts
small data pipes, and creates the windows. The other QML files draw the visible
parts of those windows and receive only the service objects they need.

## Files To Start With

- `shell.qml`: top-level service wiring, timers, data pipes, and windows.
- `GeneratedCommands.qml`: generated command/script paths from Nix.
- `CommandRunner.qml`: shared command execution and refresh signaling.
- `AudioActions.qml`, `BrightnessActions.qml`, `MediaActions.qml`,
  `PowerActions.qml`, `ConnectivityActions.qml`: domain command APIs used by
  UI components.
- `Bar.qml`: the top bar content.
- `Popovers.qml`: the popup window and the Loader that swaps popup panels.
- `QuickSettings.qml`, `CalendarPanel.qml`, `TrayPanel.qml`, `MediaPanel.qml`,
  `NotificationPanel.qml`: popup contents.
- `ToastNotifications.qml`: temporary notification cards.
- `OsdOverlay.qml`: volume, brightness, and keyboard-backlight overlay.
- `Theme.qml`: colors, sizes, animation durations, and shared color helpers.
- `Icons.qml` and `ShellIcon.qml`: SVG icon data and icon rendering.

## Shared UI Pieces

The small reusable files keep common visual patterns in one place:

- `BarCapsule.qml`: standard top-bar capsule frame.
- `IconButton.qml`: small icon-only button.
- `ActionButton.qml`: short text action button.
- `HoverTooltip.qml`: hover label bubble.
- `StyledSlider.qml`: quick-settings slider skin.
- `NotificationActions.qml`: notification action buttons.
- `MarqueeText.qml`: text that scrolls only when it is too wide.

If two panels need the same button, tooltip, slider, or bar capsule styling,
prefer changing one of these components instead of copying a new local block.

## Important Rules

Every new QML file must be added to `qmldir`. This directory has a `qmldir`
manifest, so Qt does not auto-discover new files.

Home Manager copies this directory as the Quickshell config. Generated files
such as `Theme.qml` and `GeneratedCommands.qml` are copied first, then
overwritten by `quickshell.nix` with generated content.

Keep command placeholders such as `@STATUS_SCRIPT@` in
`GeneratedCommands.qml` only. `quickshell.nix` replaces those placeholders
with real Nix store paths. Child components should call methods on the narrow
domain object they receive, such as `powerActions.runPowerProfileSet(...)`,
instead of embedding command strings or depending on `shell.qml`.

## Popup Loading

`Popovers.qml` uses a `Loader` to create the active popup panel. When the popup
closes, the Loader source is cleared so the hidden panel is destroyed instead of
kept around in memory.

Qt Loader documentation:
https://doc.qt.io/qt-6/qml-qtquick-loader.html

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
