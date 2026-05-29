# Minimal Hyprland Rice

This module is a small Hyprland baseline for the `hyprland` desktop profile. It is intentionally not a copied full rice. The goal is a Catppuccin Mocha desktop shell with the basics wired up cleanly: a top bar, launcher, notifications, tray, lock screen, idle handling, wallpapers, screenshots, removable media, and the common Wayland desktop plumbing.

## Entry Points

- `modules/nixos/hyprland.nix`: system-level Hyprland, greetd/tuigreet, PAM, dconf, GVfs, and UDisks.
- `modules/home-manager/hyprland/default.nix`: Home Manager package baseline, portals, fonts, Nautilus, and udiskie.
- `modules/home-manager/hyprland/quickshell.nix`: Hyprland config, Quickshell deployment, Waypaper/awww wallpaper setup, session services, keybinds, and small helper scripts.
- `modules/home-manager/hyprland/quickshell/shell.qml`: the Quickshell bar, popovers, native notifications, and tray.
- `modules/home-manager/hyprland/quickshell/README.md`: plain-language map of the Quickshell QML files and shared UI components.
- `modules/home-manager/hyprland/hyprlock.nix`: lock screen.
- `modules/home-manager/hyprland/hypridle.nix`: idle lock and display-off behavior.
- `modules/home-manager/hyprland/scripts/`: status, timezone, screenshot, and temporary TTY test helpers.

Enable the profile by setting the host `desktopProfile` to `"hyprland"` in `flake.nix`.

## Launch Process

The production launch path is:

```text
greetd -> tuigreet -> Hyprland -> hyprland.conf exec-once -> user services -> Quickshell QML
```

Plain English version:

1. `modules/nixos/hyprland.nix` enables Hyprland and `greetd`.
2. `greetd` shows the `tuigreet` login prompt.
3. After login, `tuigreet --cmd Hyprland` starts Hyprland directly.
4. Home Manager writes `~/.config/hypr/hyprland.conf` from `modules/home-manager/hyprland/quickshell.nix`.
5. Hyprland reads that config and runs the `exec-once` commands near the top of the file.
6. Those `exec-once` commands import the Wayland session environment into systemd and start the user services this session depends on.
7. `hypr-shell-quickshell.service` runs `quickshell --config hyprland`, which loads `~/.config/quickshell/hyprland/shell.qml`.

The setup deliberately avoids UWSM for now. That means this profile does not
depend on UWSM to activate `graphical-session.target`; the generated
`hyprland.conf` starts the user services explicitly.

The explicit service startup list is:

- `hypr-shell-awww.service`
- `hypr-shell-waypaper-restore.service`
- `hypr-shell-quickshell.service`
- `hypr-shell-vicinae.service`
- `hypr-shell-media-idle-inhibit.service`
- `hypridle.service`
- `hyprpolkitagent.service`
- `hyprsunset.service`
- `udiskie.service`

`hypr-shell-clipboard.service` is intentionally not started. Vicinae is already
being used for clipboard history, so the old `cliphist` collector is left
commented out unless you decide to bring it back.

If `local.hyprland.withUWSM` is enabled later, revisit both sides of the launch:
the `greetd` command should start the UWSM-managed Hyprland session, and the
explicit `exec-once = systemctl --user start ...` lines may no longer be the
right ownership model. Do not flip only the boolean and assume the rest of the
startup chain is unchanged.

## Helper Scripts

The shell scripts under `scripts/` (status, popup, power-profile, caffeine,
screenshot, screenrecord, timezones, etc.) are **not** standalone executables.
`quickshell.nix` reads each one with `builtins.readFile` and embeds it into a
`pkgs.writeShellApplication`. That builder generates the real store executable:
it supplies the `#!${runtimeShell}` (bash) shebang, `set -euo pipefail`, and the
`runtimeInputs` PATH, then runs ShellCheck at build time.

Because the production entry point is the builder — not the file's own
interpreter line — each script starts with:

```sh
# shellcheck shell=bash
```

and deliberately **omits** both a `#!/usr/bin/env bash` shebang and an in-body
`set -euo pipefail`:

- A shebang would be inert here (it lands mid-file as a comment after the
  builder's own prelude) and would falsely advertise a standalone-executable
  contract the file does not fulfil — it isn't `chmod +x` in this flow.
- The `set -euo pipefail` would be redundant; `writeShellApplication` already
  applies it in the production path.
- The `# shellcheck shell=bash` directive still gives ShellCheck the dialect it
  needs when linting the raw file (editor / CI / `shellcheck foo.sh`), avoiding
  `SC2148` and the POSIX-`sh` false positives on bash-isms like `[[ ]]`, `<<<`,
  arrays, and `${var//pat/repl}`.

Caveat: the Fast Host Testing harness runs these via `exec bash "$script"`, so
they do not get strict mode in the TTY path (same as production relies on the
builder). If a script ever becomes directly invoked by its own path, restore a
real shebang.

The two host-side harness scripts — `hypr-shell-generate-quickshell.sh` and
`hypr-shell-tty-test.sh` — are the exception. They are run directly (not
embedded in a builder), so they intentionally keep a `#!/usr/bin/env bash`
shebang and their own `set -euo pipefail`.

## Desktop Shape

Once launched, the session shape is a standalone Hyprland desktop with a custom
Quickshell top bar, Vicinae launcher, native notification handling, a system
tray, hyprlock, hypridle, Waypaper/awww wallpapers, and a small set of helper scripts.

## Top Bar

Quickshell runs as `quickshell --config hyprland` and loads `~/.config/quickshell/hyprland/shell.qml`.

The profile installs Quickshell from Nixpkgs through `home.packages`. It also enables Home Manager's Qt integration with `qt.enable = true` and installs `qt6.qtdeclarative`, so `qmlls` can see QML modules through `QML2_IMPORT_PATH`. This follows Quickshell's Nix editor setup guidance while staying on the repo's pinned Nixpkgs package instead of adding Quickshell's upstream flake input.

The bar is top-aligned and includes:

- A floating, icon-first top bar.
- Dynamic workspace pills for active and occupied workspaces only.
- Center date/time in `May 21 11:46 PM` style.
- Navigable GNOME-like calendar popover with fixed extra zones:
  - Birmingham, UK
  - Lagos, Nigeria
  - San Francisco, CA
- MPRIS/media indicator and basic media controls through Quickshell's native
  MPRIS service.
- Always-visible CPU, memory, and temperature readouts.
- Caffeine capsule for manually blocking idle lock/timeout.
- GNOME-like quick settings popover for PipeWire volume, built-in backlight
  brightness, network/VPN, Bluetooth, DND, power profile, UPower battery,
  system stats, and `hyprshutdown`.
- Native Quickshell notification history and popups.
- System tray overflow, shown only when tray items exist.

The tray uses Quickshell's StatusNotifier support. It is for modern AppIndicator/StatusNotifier tray items, not legacy XEmbed tray icons.

The bar uses small SVG icons rendered by Quickshell. It intentionally does not
use Nerd Font glyph icons. Glyph icons are special characters inside patched
fonts; when the patched font is missing or Qt chooses a different font, those
icons show up as boxes or incorrect symbols. SVG icons avoid that dependency.

## Fast Host Testing

For faithful host-side testing on a non-NixOS machine, run Hyprland from a real
TTY and launch Quickshell inside it. This helper is deliberately not installed
by Home Manager and is not part of the production NixOS setup.

A TTY is the full-screen text login reached with `Ctrl+Alt+F3`, `Ctrl+Alt+F4`, etc. It is not a terminal window inside GNOME. The TTY helper intentionally refuses to run when `DISPLAY` or `WAYLAND_DISPLAY` is set because that means you are still inside a graphical desktop.

Typical flow from the Fedora host:

```sh
Ctrl+Alt+F3
login
cd ~/Desktop/labs/nixos-config
./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh
```

The helper reads the working-tree `shell.qml`, generates a temporary Quickshell config under `$XDG_RUNTIME_DIR/hypr-shell-tty-test`, writes a temporary Hyprland config, and launches:

```sh
Hyprland --config "$XDG_RUNTIME_DIR/hypr-shell-tty-test/hyprland/hyprland.conf"
```

That temporary Hyprland config launches Quickshell with real `PanelWindow`/layer-shell behavior. Quickshell startup logs for this test session are written under:

```text
$XDG_RUNTIME_DIR/hypr-shell-tty-test/quickshell.log
```

If the wallpaper appears but the top bar does not, check that log first. It should show whether Quickshell started, whether it exited, and which temporary config directory it loaded.

The helper writes the generated configs under:

```text
$XDG_RUNTIME_DIR/hypr-shell-tty-test/quickshell
$XDG_RUNTIME_DIR/hypr-shell-tty-test/hyprland
```

For layer-shell state while the test session is running, switch to another TTY and run `hyprctl layers`.

If the normal bar still does not appear, run the TTY helper in smoke-test mode:

```sh
HYPR_SHELL_TTY_SMOKE=1 ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh
```

Smoke-test mode replaces the full shell with one bright red `PanelWindow` named
`quickshell-smoke-test`. If that red bar appears, Quickshell and Hyprland can
create layer-shell panels and the bug is inside the full shell QML. If it does
not appear, the problem is below the shell design layer: Quickshell, Hyprland,
the host TTY session, or the Fedora package/build.

By default, the TTY test uses this mock wallpaper:

```text
/home/olaolu/Pictures/wallpapers/skeleton-prophet.jpg
```

Quickshell is still launched before the wallpaper process. That ordering matters
because the bar test should not depend on wallpaper startup.

Pass a wallpaper explicitly when you want to test a different image:

```sh
./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh --wallpaper /path/to/image.jpg
```

The wallpaper path can also come from an environment variable:

```sh
HYPR_SHELL_TTY_WALLPAPER=/path/to/image.jpg ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh
```

The temporary TTY session applies this test wallpaper with `swaybg`. This is
separate from the normal Hyprland profile, which uses Waypaper with `awww` for
regular wallpapers. The helper expects `swaybg` to already be available on the
non-NixOS test host.

When you edit QML or helper scripts, close the temporary Hyprland session and
run `hypr-shell-tty-test` again. That keeps the test path simple and predictable.

To close the temporary Hyprland test session, press either:

```text
Super+Escape
Super+Shift+Q
```

Those keys are bound to Hyprland's `exit` command in the generated temporary config. If the keybinds do not work, switch to another TTY with `Ctrl+Alt+F3`, `Ctrl+Alt+F4`, or similar, log in, and run:

```sh
pkill Hyprland
```

Switch back to GNOME with its original virtual-terminal shortcut, commonly `Ctrl+Alt+F2` on Fedora Workstation.

The TTY helper uses this monitor rule by default:

```sh
monitor = ,preferred,auto,1
```

Override it only when needed:

```sh
./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh --monitor ',1920x1080@60,auto,1'
```

This is meant for bar/popover styling and real Hyprland shell behavior. It is not a full replacement for the VM. Use the VM when changing NixOS boot, greetd, PAM, Home Manager activation, package installation, or systemd service wiring.

To remove this temporary TTY test harness after it has served its purpose:

1. Delete `modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh`.
2. Delete `modules/home-manager/hyprland/scripts/hypr-shell-generate-quickshell.sh`.
3. Delete this `Fast Host Testing` section.

## Keybinds

| Binding | Action |
| --- | --- |
| `Super` | Open Vicinae launcher with `vicinae open` |
| `Super+Space` | Open Vicinae launcher fallback with `vicinae open` |
| `Super+Return` | Open Kitty |
| `Super+Shift+V` | Open Vicinae clipboard history |
| `Super+Shift+W` | Open Waypaper |
| `F6` | Region screenshot, then annotate/copy/save in Satty |
| `Shift+F6` | Full screenshot, then annotate/copy/save in Satty |
| `Ctrl+F6` | Active-window screenshot, then annotate/copy/save in Satty |
| `Super+Shift+R` | Record a selected region |
| `Super+Ctrl+R` | Record the full screen |
| `Super+Alt+R` | Stop the active screen recording |
| `Super+E` | Open Nautilus |
| `Super+Q` | Toggle Quickshell quick settings |
| `Super+N` | Open network connection editor |
| `Super+B` | Open Blueman manager |
| `Super+M` | Open Mission Center |
| `Super+Escape` | Open Hyprshutdown |
| `XF86PowerOff` | Open Hyprshutdown |
| `Super+L` | Lock session |
| `Super+Shift+Q` | Close focused window |
| `Super+F` | Toggle fullscreen |
| `Super+V` | Toggle floating |
| `Super+1..5` | Switch workspace |
| `Super+Shift+1..5` | Move focused window to workspace |
| `Super+Left Mouse` | Move window |
| `Super+Right Mouse` | Resize window |

## Power Actions

The Quickshell power controls intentionally use different tools for different
jobs:

- Logout uses `hyprshutdown`.
- Reboot uses `hyprshutdown --post-cmd '<generated systemctl path> reboot'`.
- Power off uses `hyprshutdown --post-cmd '<generated systemctl path> poweroff'`.
- Suspend uses `systemctl suspend`.
- Lock uses `loginctl lock-session`.

`hyprshutdown` is used for logout, reboot, and power off because it asks apps to
close before Hyprland exits. A raw `hyprctl dispatch exit` quits Hyprland more
abruptly, so it is kept only in the temporary TTY test harness as an emergency
way to leave that throwaway session. Suspend is different: it should keep the
session alive, so it goes straight through systemd instead of exiting Hyprland.

## Wallpapers

Wallpapers come from the directory referenced by `$WALLPAPERS_DIR`. The dotfiles module currently sets that to `~/Pictures/Wallpapers`.

Waypaper is the wallpaper picker. `awww` is the Wayland daemon that actually
draws the selected wallpaper on screen.

Home Manager writes `~/.config/waypaper/config.ini` so Waypaper starts with the
right wallpaper folder and the `awww` backend. Waypaper stores the selected
wallpaper in its own state file, which keeps the Nix-written config from needing
to be edited by the app.

When a wallpaper is selected, Waypaper runs a small post-command that updates:

```text
$XDG_CACHE_HOME/hypr-shell/lock-wallpaper
```

Hyprlock reads that symlink for the lock-screen background.

Waypaper escapes the `$wallpaper` value before running `post_command`, so the
config passes `$wallpaper` unquoted. That looks odd, but it is what keeps paths
with spaces working.

Useful commands:

```sh
waypaper
waypaper --random
waypaper --restore
```

`Super+Shift+W` opens Waypaper. Waypaper is also exposed as a normal desktop
entry named `Waypaper`, so Vicinae can open it from app search. The random
wallpaper command is present in the generated Hyprland config as a commented
keybind, but it is intentionally left unbound until a key is chosen for it.

## Screenshots

The screenshot workflow uses `grim`, `slurp`, `wl-clipboard`, and Satty.

Screenshots are piped into Satty for annotation. Pressing Enter copies the edited image to the clipboard and also saves it under:

```text
~/Pictures/Screenshots/
```

The selection UI uses Catppuccin-ish colors to match the shell.

After Satty closes successfully, the script sends a short "Screenshot saved"
notification. Use the `Open Folder` action on that notification to open the
screenshots folder in the file manager.

## Screen Recording

Lightweight recording uses `wf-recorder`.

Recordings are saved under:

```text
~/Videos/Screencasts/
```

The recording command sends a notification when recording starts. The same
command keeps running while `wf-recorder` records. When `Super+Alt+R` stops
`wf-recorder`, the recorder finalizes the video file, the original command
continues, and then it sends the "Recording saved" notification.
Use the `Open Folder` action on that notification to open the screencasts folder
in the file manager.

Useful commands:

```sh
hypr-shell-record area
hypr-shell-record full
hypr-shell-record stop
```

OBS is still the better tool for scene-based recording, streaming, camera
layouts, and audio mixing. `wf-recorder` is the quick clip tool.

## Lock And Idle

`hypridle` handles idle behavior:

- after 15 minutes, lock the session;
- before sleep, lock the session.

Idle inhibitors are honored explicitly. `hypr-shell-media-idle-inhibit.service`
uses `wayland-pipewire-idle-inhibit` to block idle while PipeWire media is
playing. The top-bar caffeine capsule controls `hypr-shell-caffeine.service`,
which holds a manual systemd idle inhibitor until toggled off.

Display-off-on-idle is present as a commented `hypridle` listener because VM
displays can fail to wake cleanly after DPMS off. Re-enable it on bare metal if
that behavior is wanted.

`hyprlock` uses the current wallpaper symlink as its background, with blur, a centered password field, and time/date labels. NixOS defines `security.pam.services.hyprlock = { };` so hyprlock can authenticate.

## Power Profiles

The quick settings popover shows the current power profile and cycles it on click.

The widget is intentionally backend-generic:

- primary backend: `powerprofilesctl`, provided by `power-profiles-daemon`;
- fallback backend: `asusctl`, only if the command is already available, the machine reports itself as ASUS hardware, and the generic backend cannot be used.

This keeps Quickshell decoupled from host-specific ASUS policy. On Boreas, the system profile already enables `power-profiles-daemon` and `asusd`, with ASUS power behavior defined in `hosts/boreas/default.nix`.

Useful commands:

```sh
hypr-shell-power-profile status
hypr-shell-power-profile cycle
powerprofilesctl get
powerprofilesctl list
asusctl profile get
asusctl profile next
asusctl profile set Balanced
```

The TTY test uses the host's current PATH instead of Home Manager's Nix wrapper.
Power profile switching in the TTY test only works if the host already has a
usable `powerprofilesctl` or a working `asusctl`/`asusd` setup.

## Removable Media

Nautilus is the GUI file manager. Because Nautilus is a GNOME app, the Hyprland system profile enables:

- `programs.dconf.enable = true`
- `services.gvfs.enable = true`
- `services.udisks2.enable = true`

Home Manager enables `services.udiskie` with automount and notifications. The tray is disabled for udiskie because Quickshell owns the tray UI, but the daemon still automounts removable devices and sends notifications.

## Portals And Wayland Plumbing

The Home Manager profile enables portals with:

- `xdg-desktop-portal-hyprland`
- `xdg-desktop-portal-gtk`

Hyprland handles compositor-specific portal features such as screen sharing. GTK covers generic desktop interfaces such as file pickers.

The profile also installs Qt Wayland support:

- `libsForQt5.qtwayland`
- `qt6.qtwayland`

Font coverage is explicit:

- `noto-fonts`
- `noto-fonts-color-emoji`
- `nerd-fonts.symbols-only`
- `font-awesome`

## Updating To Unstable

The current baseline uses the primary `nixpkgs` input for `programs.hyprland`. Some adjacent tools already come from `nixpkgs-unstable` when the stable channel does not have the package or when the tool is intentionally newer.

Do not switch only the Hyprland compositor casually. Hyprland is an ecosystem, and version skew can show up as portal, lock screen, shell, or config-syntax problems. If you move Hyprland to unstable, move the stack coherently and verify it as one change.

At the time this README was written, the pinned inputs differed like this:

```text
stable Hyprland:   0.52.1
unstable Hyprland: 0.55.1
stable portal:     1.3.11
unstable portal:   1.3.12
stable hyprlock:   0.9.2
unstable hyprlock: 0.9.5
stable quickshell: 0.2.1
unstable quickshell: 0.3.0
```

The safer migration path is:

1. Make `modules/nixos/hyprland.nix` accept `unstable` as an argument.
2. Set `programs.hyprland.package = unstable.hyprland`.
3. If the NixOS module supports it, set the matching portal package to `unstable.xdg-desktop-portal-hyprland`.
4. Move Home Manager Hyprland ecosystem packages together where practical:

```nix
programs.hyprlock.package = unstable.hyprlock;
services.hypridle.package = unstable.hypridle;
home.packages = [
  unstable.quickshell
  unstable.xdg-desktop-portal-hyprland
];
```

The exact option names can change across NixOS/Home Manager releases, so verify them with:

```sh
nixos-option programs.hyprland
home-manager options | rg 'hypr(lock|idle)|quickshell|portal'
```

After changing the stack, run the build and parser verification from the next section before switching generations.

## QML IDE Integration

The Quickshell docs recommend a QML grammar plus `qmlls` for editing shell code. This profile provides the language server via `qt6.qtdeclarative` and exposes QML imports via `qt.enable = true`.

For Neovim, point `qmlls` at the executable with the modern `-E` flag:

```lua
require("lspconfig").qmlls.setup {
  cmd = { "qmlls", "-E" },
}
```

For VS Code, install the official QML Support extension and enable its `qt-qml.qmlls.useQmlImportPathEnvVar` setting.

The Quickshell docs still call out caveats: the language server does not provide Quickshell type docs, root imports may not resolve, and `PanelWindow` in particular may be reported incorrectly. Treat `qmlls` as useful linting/completion support, not perfect Quickshell validation.

## Deliberate Exclusions

These are intentionally not part of this baseline:

- `hyprpaper`: replaced by Waypaper with `awww`.
- `swaync`, `dunst`, `mako`, `fnott`: replaced by Quickshell-native notifications.
- Waybar, AGS, Eww, HyprPanel, Noctalia, ashell: replaced by this small Quickshell shell.
- Wofi, Rofi, Fuzzel, Walker, Anyrun, Hyprlauncher: replaced by Vicinae.
- `hyprpwcenter`: excluded; `pavucontrol` remains in the broader user package set.
- SDDM theming: this profile uses greetd/tuigreet.
- GTK/Qt theming: deliberately postponed.
- Wlogout/custom power menu: replaced by a small `hyprshutdown` affordance.
- UWSM: deliberately postponed until the base session proves stable.
- Dedicated streaming workspace mode: possible later via a headless/virtual output, but not part of this baseline.

## Verification

The current verification approach uses a temporary copy of the repo and flips `desktopProfile` to `"hyprland"` there, so local `flake.lock` does not need to be touched.

Format and lint:

```sh
nixfmt modules/home-manager/hyprland/default.nix \
  modules/home-manager/hyprland/hypridle.nix \
  modules/home-manager/hyprland/hyprlock.nix \
  modules/home-manager/hyprland/quickshell.nix \
  modules/nixos/hyprland.nix

shfmt -w modules/home-manager/hyprland/scripts/*.sh
shellcheck -s bash modules/home-manager/hyprland/scripts/*.sh
```

Build and parse check:

```sh
tmpdir=$(mktemp -d /tmp/nixos-config-hypr-verify.XXXXXX)
cp -a . "$tmpdir/repo"
perl -0pi -e 's/desktopProfile = "gnome";/desktopProfile = "hyprland";/' "$tmpdir/repo/flake.nix"

home_profile=$(nix build "path:$tmpdir/repo#homeConfigurations.olaolu@boreas.activationPackage" --no-link --print-out-paths)
nix build "path:$tmpdir/repo#nixosConfigurations.boreas.config.system.build.toplevel" --no-link
hyprland=$(nix build "path:$tmpdir/repo#nixosConfigurations.boreas.pkgs.hyprland" --no-link --print-out-paths | tail -n 1)

"$hyprland/bin/Hyprland" --verify-config --config "$home_profile/home-files/.config/hypr/hyprland.conf"
```

Expected result:

```text
config ok
```

## Known Runtime Risks

- Quickshell QML is build-rendered but not fully live-tested here; actual tray item menus and notification actions should be checked inside a running Hyprland session.
- The status script reports the first reasonable temperature sensor it finds. On some hardware, `lm_sensors` labels may need tuning.
- The tray handles StatusNotifier/AppIndicator items. Old XEmbed-only tray apps may not appear.
- Selective workspace streaming is not implemented. The likely future route is a dedicated headless Hyprland output captured by OBS.
- NVIDIA-specific Hyprland environment tuning is mostly not encoded here yet. The host already uses proprietary NVIDIA drivers with modesetting; additional Hyprland NVIDIA tweaks should be added only after testing real symptoms.

## References

Research notebook:

- Quickshell Hyprland Rice Reference: https://notebooklm.google.com/notebook/3976ddbc-f445-4d0d-b98b-7a15800809a7

Hyprland:

- Hyprland must-have utilities: https://wiki.hypr.land/Useful-Utilities/Must-have/
- Hyprland useful utilities: https://wiki.hypr.land/Useful-Utilities/
- Hyprland screenshots and recording: https://wiki.hypr.land/Useful-Utilities/Screenshots-and-Recording/
- Hyprland wallpapers: https://wiki.hypr.land/Useful-Utilities/Wallpapers/
- Hyprland clipboard managers: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/
- Hyprland file managers: https://wiki.hypr.land/Useful-Utilities/File-Managers/
- Hyprland binds: https://wiki.hypr.land/Configuring/Binds/
- Hyprland xdg-desktop-portal-hyprland: https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/
- Hyprland hypridle: https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
- Hyprland hyprlock: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
- Hyprland hyprsunset: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
- Hyprland hyprpolkitagent: https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/
- Hyprland hyprshutdown: https://wiki.hypr.land/Hypr-Ecosystem/hyprshutdown/
- Hyprland NVIDIA notes: https://wiki.hypr.land/Nvidia/

Quickshell and QML:

- Quickshell install and editor setup: https://quickshell.org/docs/v0.1.0/guide/install-setup/
- Quickshell introduction: https://quickshell.org/docs/guide/introduction/
- Quickshell core object: https://quickshell.org/docs/v0.2.0/types/Quickshell/Quickshell/
- Quickshell PanelWindow: https://quickshell.org/docs/v0.2.0/types/Quickshell/PanelWindow/
- Quickshell PopupWindow: https://quickshell.org/docs/v0.2.0/types/Quickshell/PopupWindow/
- Quickshell Process: https://quickshell.org/docs/v0.2.0/types/Quickshell.Io/Process/
- Quickshell NotificationServer: https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.Notifications/NotificationServer/
- Quickshell SystemTray: https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.SystemTray/SystemTray/
- Quickshell SystemTrayItem: https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.SystemTray/SystemTrayItem/
- Quickshell Hyprland module: https://quickshell.org/docs/v0.2.0/types/Quickshell.Hyprland/
- Quickshell Hyprland workspace type: https://quickshell.org/docs/v0.2.0/types/Quickshell.Hyprland/HyprlandWorkspace/
- Qt QML syntax basics: https://doc.qt.io/qt-6/qtqml-syntax-basics.html
- Qt QML reference: https://doc.qt.io/qt-6/qmlreference.html
- Qt AI skills for QML coding/review: https://github.com/TheQtCompanyRnD/agent-skills

Vicinae:

- Vicinae deeplinks: https://docs.vicinae.com/deeplinks
- Vicinae CLI source: https://github.com/vicinaehq/vicinae/blob/main/src/cli/src/cli.cpp

Screenshot tooling:

- Satty: https://github.com/Satty-org/Satty
- Grim: https://sr.ht/~emersion/grim/
- Slurp: https://github.com/emersion/slurp
- wl-clipboard: https://github.com/bugaevc/wl-clipboard

Design references:

- ilyamiro NixOS configuration: https://github.com/ilyamiro/nixos-configuration
- ilyamiro preview screenshot: https://github.com/ilyamiro/nixos-configuration/blob/master/previews/screenshot1.png
- ilyamiro TopBar.qml: https://github.com/ilyamiro/nixos-configuration/blob/master/config/sessions/hyprland/scripts/quickshell/TopBar.qml
- ilyamiro CalendarPopup.qml: https://github.com/ilyamiro/nixos-configuration/blob/master/config/sessions/hyprland/scripts/quickshell/calendar/CalendarPopup.qml
- ilyamiro VolumePopup.qml: https://github.com/ilyamiro/nixos-configuration/blob/master/config/sessions/hyprland/scripts/quickshell/volume/VolumePopup.qml
- ilyamiro NetworkPopup.qml: https://github.com/ilyamiro/nixos-configuration/blob/master/config/sessions/hyprland/scripts/quickshell/network/NetworkPopup.qml
