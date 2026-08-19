# Minimal Hyprland Rice

This module is the `hyprland` desktop profile: compositor config, keybinds,
hyprlock, hypridle, hyprsunset, Vicinae, portals, a wallpaper pipeline, a few
helper scripts, and the `silere-shell` bar. The shell runs as the session's
sole shell; `silere.nix` declares its first-generation defaults, which the
shell's own Settings UI can still override per-key at runtime.

## Entry Points

- `modules/nixos/hyprland.nix`: system-level Hyprland, greetd/tuigreet, PAM, dconf, GVfs, and UDisks.
- `modules/home-manager/hyprland/default.nix`: thin entry point -- `enable`/`wallpaper` options, imports, `hyprland-session.target`, session plumbing, shared packages, fonts, Nautilus, mime defaults, udiskie, and portals.
- `modules/home-manager/hyprland/modules/commands.nix`: shared helper-script packages (screenshot, screenrecord, caffeine) and the `local.hyprland.commands` option tree other modules read from.
- `modules/home-manager/hyprland/modules/compositor.nix`: compositor config (monitors, input, decoration, animations, window rules) -- everything in `wayland.windowManager.hyprland` except key chords.
- `modules/home-manager/hyprland/modules/keybindings.nix`: every Hyprland key chord.
- `modules/home-manager/hyprland/modules/hyprlock.nix`: lock screen.
- `modules/home-manager/hyprland/modules/hypridle.nix`: idle lock and display-off behavior.
- `modules/home-manager/hyprland/modules/hyprshell.nix`: the hyprshell Alt-Tab window switcher -- packaging, config, and the user service. Launcher/overview mode stays off; Vicinae is the sole launcher.
- `modules/home-manager/hyprland/modules/hyprsunset.nix`: display color temperature schedule.
- `modules/home-manager/hyprland/modules/session-services.nix`: extra Hyprland-session user services (media idle-inhibit, manual caffeine inhibitor).
- `modules/home-manager/hyprland/modules/silere.nix`: the `silere-shell` Quickshell bar -- packaging, declared defaults, and the user service.
- `modules/home-manager/hyprland/modules/wallpaper.nix`: the wallpaper pipeline (`wallpaper-set`, awww, matugen retinting, hyprlock's stable path). The human entry points are silere-shell's own picker (keybindings.nix) now, not Vicinae.
- `modules/home-manager/vicinae.nix`: generic Vicinae program config, imported and targeted at `hyprland-session.target` by this profile.
- `modules/home-manager/hyprland/scripts/`: keybind helper scripts (caffeine, screenshot, screenrecord).

Enable the profile by setting the host `desktopProfile` to `"hyprland"` in `flake.nix`.

## Launch Process

```text
greetd -> tuigreet -> Hyprland -> Home Manager hyprland.lua -> hyprland-session.target -> user services
```

Home Manager writes `~/.config/hypr/hyprland.lua`. Hyprland's generated
startup hook imports the Wayland session environment into systemd and starts
`hyprland-session.target`, which the following user services attach to:
`silere-shell.service`, `vicinae.service`, `hypr-shell-awww.service`,
`hypr-shell-wallpaper-restore.service`,
`hypr-shell-media-idle-inhibit.service`, `hypr-shell-caffeine.service`,
`hypridle.service`, `hyprpolkitagent.service`, `hyprsunset.service`,
`hyprshell.service`, `udiskie.service`.

The setup deliberately avoids UWSM.

## Keybinds

See `./modules/keybindings.nix`. Hardware media/brightness keys (volume, brightness,
keyboard backlight) are bound directly to `wpctl`/`brightnessctl` since there
is no shell OSD to own them. Super+Shift+W opens silere-shell's own wallpaper
picker (see Wallpaper Pipeline below). A handful of other chords that used to
open shell surfaces (settings, wifi, bluetooth, session menu) are
intentionally unbound until the shell's design-build phase wires their new
targets.

Alt+Tab (hold Alt, tap Tab to cycle, Shift+Tab or `` Alt+` `` to reverse,
release Alt to switch) opens hyprshell's GNOME-style window switcher across
every workspace, MRU-ordered. This chord is **not** in `keybindings.nix`:
hyprshell registers it with Hyprland itself at runtime from its own config
(see `./modules/hyprshell.nix`), the one exception to "every key chord lives
in keybindings.nix" in this profile.

The switcher's GTK4 stylesheet (`~/.config/hyprshell/styles.css`, also
declared in `./modules/hyprshell.nix`) reproduces GNOME Shell's real
app-switcher look -- a near-opaque dark panel with a large corner radius and
soft drop shadow, and a white-at-20%-alpha rounded highlight on the selected
window -- with the numbers sourced from GNOME's own
`gnome-shell-sass/widgets/_switcher-popup.scss` and `_osd.scss`. Tile and icon
size come from the config's `windows.scale`, not CSS -- hyprshell computes the
icon's pixel size in Rust from monitor geometry and that one field.

`./modules/hyprshell.nix` also `overrideAttrs`s `pkgs.hyprshell` with
`./modules/hyprshell-switcher-tiles.patch`, applied to
`crates/windows-lib/src/switch/clients.rs`. It fixes two things neither
config nor CSS can reach: upstream renders each tile's app name as a GtkFrame
label-widget, which GTK4 always pins to the frame's top edge with no CSS
escape hatch, so the patch swaps that Frame for a plain vertical Box (icon,
then label) so the name sits below the icon like GNOME's real switcher; and
upstream sizes each tile's Button from raw monitor width/height regardless of
content (~465x290px on a 2560x1600 monitor), which the patch deletes so the
tile sizes to its icon+label Box instead, capping the label's width to the
icon's so a long window title ellipsizes rather than stretching the tile.
It's minimal (one `view!` block) but source-level, so it needs rebasing by
hand on every hyprshell version bump -- check it still applies before
bumping `pkgs.hyprshell`.

## Helper Scripts

Scripts under `scripts/` are **not** standalone executables; the Home Manager
modules read them with `builtins.readFile` and embed them into
`pkgs.writeShellApplication`, which supplies the shebang, `set -euo pipefail`,
and `runtimeInputs` PATH. Each script starts with `# shellcheck shell=bash`
and omits its own shebang/`set` line for that reason.

- `hypr-shell-screenshot`: grim/slurp/Satty; copies the raw capture to the clipboard instantly, with Satty as an optional annotate/save step to `~/Pictures/Screenshots/`.
- `hypr-shell-record`: wf-recorder, saves to `~/Videos/Screencasts/`.
- `hypr-shell-caffeine`: manual systemd idle inhibitor toggle.

`wallpaper-set` itself is inlined in `wallpaper.nix` rather than kept here, since it is the one script that needs a Nix-level value (the stable wallpaper path) -- see Wallpaper Pipeline below. There used to be a pair of Vicinae wallpaper script commands here too; they are gone, replaced by silere-shell's own picker.

## Lock, Idle, And Wallpaper

`hypridle` locks the session after 15 minutes idle or before sleep, honoring
`hypr-shell-media-idle-inhibit.service` (PipeWire playback) and
`hypr-shell-caffeine.service` (manual toggle).

`hyprlock`'s background is `local.hyprland.wallpaper`, a stable, user-writable
path shared across the session. Home Manager seeds it once, on first boot,
with a bundled `nixos-artwork` placeholder; from then on `wallpaper-set` owns
it (see below).

## Wallpaper Pipeline

`wallpaper.nix` packages `wallpaper-set <image-path>`, the single entry point
the rest of the pipeline funnels through: it validates the path, points awww
at the new image, runs `matugen image` to retint `silere-shell`, then
converts (not copies) the image into `local.hyprland.wallpaper` so hyprlock's
background stays in sync and its `.png` extension always matches the real
pixel format. `hypr-shell-awww.service` runs `awww-daemon`;
`hypr-shell-wallpaper-restore.service` pushes the stable path back into awww
on login, so the last wallpaper survives a restart. `xdg.configFile
"matugen/config.toml"` wires matugen's `[templates.silere-shell]` entry at
the packaged silere-shell derivation's bundled template -- this replaces the
role the fork's own `scripts/install.sh` normally plays. `silere-shell`'s
`MatugenPalette.qml` live-watches matugen's output JSON and repaints as soon
as it changes, no shell restart needed.

The human entry point is silere-shell's own wallpaper picker now, not
Vicinae: Super+Shift+W (keybindings.nix) opens a frosted grid over
`$WALLPAPERS_DIR`, click an image to apply it, Ctrl+F filters by name, and a
Random button inside the picker covers the zero-input case (also reachable
headless via `... ipc call wallpapers random`). It is also launchable from
Vicinae's app search via the `silere-wallpapers` desktop entry
(keybindings.nix), but the picker itself is shell UI, not a Vicinae
script command. `local.hyprland.silere.wallpaperCommand` (silere.nix) points
the picker's apply step at this exact `wallpaper-set` binary, and
`local.hyprland.silere.wallpapersDir` points it at the same directory
`$WALLPAPERS_DIR` resolves to (both packaging-only settings keys, wired via
`local.hyprland.commands.wallpaperSetScript`/`wallpapersDir` in
`commands.nix` -- see that module's comments). This replaced a pair of
Vicinae script commands: Vicinae's script-command argument types only
support a single static text field, never a live directory listing, so a
real picker over `$WALLPAPERS_DIR` was never something Vicinae itself could
render -- only the shell's own overlay can.

## Portals And Fonts

Portals: `xdg-desktop-portal-hyprland` (from Home Manager's Hyprland module)
plus `xdg-desktop-portal-gtk` as the fallback for generic pickers.

Fonts: `noto-fonts`, `noto-fonts-color-emoji`, `nerd-fonts.symbols-only`, `font-awesome`.

## Verification

```sh
nixfmt modules/home-manager/hyprland/default.nix \
  modules/home-manager/hyprland/modules/commands.nix \
  modules/home-manager/hyprland/modules/compositor.nix \
  modules/home-manager/hyprland/modules/hypridle.nix \
  modules/home-manager/hyprland/modules/hyprlock.nix \
  modules/home-manager/hyprland/modules/hyprshell.nix \
  modules/home-manager/hyprland/modules/hyprsunset.nix \
  modules/home-manager/hyprland/modules/keybindings.nix \
  modules/home-manager/hyprland/modules/session-services.nix \
  modules/home-manager/hyprland/modules/silere.nix \
  modules/home-manager/hyprland/modules/wallpaper.nix \
  modules/nixos/hyprland.nix

shfmt -w modules/home-manager/hyprland/scripts/*.sh
shellcheck -s bash modules/home-manager/hyprland/scripts/*.sh

nix eval .#homeConfigurations."olaolu@boreas".activationPackage.drvPath
nix build .#homeConfigurations."olaolu@boreas".activationPackage --no-link
```

## References

- Home Manager Hyprland module: <https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/hyprland.nix>
- Hyprland wiki: <https://wiki.hypr.land/>
- Vicinae: <https://docs.vicinae.com/>
- Satty: <https://github.com/Satty-org/Satty>
- hyprshell: <https://github.com/H3rmt/hyprshell> (config schema: `docs/CONFIGURE.md`; struct source of truth: `crates/config-lib/src/io/config.rs`)
