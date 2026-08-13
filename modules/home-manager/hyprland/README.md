# Minimal Hyprland Rice

This module is the `hyprland` desktop profile: compositor config, keybinds,
hyprlock, hypridle, hyprsunset, Vicinae, portals, a wallpaper pipeline, a few
helper scripts, and the `silere-shell` bar. The shell runs as the session's
sole shell; `silere.nix` declares its first-generation defaults, which the
shell's own Settings UI can still override per-key at runtime.

## Entry Points

- `modules/nixos/hyprland.nix`: system-level Hyprland, greetd/tuigreet, PAM, dconf, GVfs, and UDisks.
- `modules/home-manager/hyprland/default.nix`: Home Manager Hyprland config, `hyprland-session.target`, session plumbing, shared packages, fonts, Nautilus, and udiskie.
- `modules/home-manager/hyprland/keybindings.nix`: every Hyprland key chord.
- `modules/home-manager/hyprland/hyprlock.nix`: lock screen.
- `modules/home-manager/hyprland/hypridle.nix`: idle lock and display-off behavior.
- `modules/home-manager/hyprland/silere.nix`: the `silere-shell` Quickshell bar -- packaging, declared defaults, and the user service.
- `modules/home-manager/hyprland/wallpaper.nix`: the wallpaper pipeline (`wallpaper-set`, awww, matugen retinting, hyprlock's stable path) and the Vicinae wallpaper commands.
- `modules/home-manager/vicinae.nix`: generic Vicinae program config, imported and targeted at `hyprland-session.target` by this profile.
- `modules/home-manager/hyprland/scripts/`: keybind and Vicinae helper scripts (caffeine, screenshot, screenrecord, wallpaper commands).

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
`udiskie.service`.

The setup deliberately avoids UWSM.

## Keybinds

See `./keybindings.nix`. Hardware media/brightness keys (volume, brightness,
keyboard backlight) are bound directly to `wpctl`/`brightnessctl` since there
is no shell OSD to own them. Super+Shift+W opens the "Random Wallpaper"
Vicinae script command (see Wallpaper Pipeline below). A handful of other
chords that used to open shell surfaces (settings, wifi, bluetooth, session
menu) are intentionally unbound until the shell's design-build phase wires
their new targets.

## Helper Scripts

Scripts under `scripts/` are **not** standalone executables; the Home Manager
modules read them with `builtins.readFile` and embed them into
`pkgs.writeShellApplication`, which supplies the shebang, `set -euo pipefail`,
and `runtimeInputs` PATH. Each script starts with `# shellcheck shell=bash`
and omits its own shebang/`set` line for that reason.

- `hypr-shell-screenshot`: grim/slurp/Satty, saves to `~/Pictures/Screenshots/`.
- `hypr-shell-record`: wf-recorder, saves to `~/Videos/Screencasts/`.
- `hypr-shell-caffeine`: manual systemd idle inhibitor toggle.
- `vicinae-random-wallpaper`, `vicinae-set-wallpaper`: the two Vicinae wallpaper script commands (see Wallpaper Pipeline below). `wallpaper-set` itself is inlined in `wallpaper.nix` rather than kept here, since it is the one script that needs a Nix-level value (the stable wallpaper path).

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

Two Vicinae script commands (installed under
`~/.local/share/vicinae/scripts/`, scanned by Vicinae itself) call
`wallpaper-set` for a human: "Random Wallpaper" (zero-input, picks from
`$WALLPAPERS_DIR`) is bound to Super+Shift+W via its `vicinae://` deeplink;
"Set Wallpaper" takes a filename/path as a Vicinae script-command text
argument and is reachable from Vicinae's own search. Vicinae's
script-command dropdown argument type only supports a single static option,
not a live directory listing, so a full picker over `$WALLPAPERS_DIR` isn't
something it can render declaratively -- a text argument is the cleanest
mechanism it actually supports here.

## Portals And Fonts

Portals: `xdg-desktop-portal-hyprland` (from Home Manager's Hyprland module)
plus `xdg-desktop-portal-gtk` as the fallback for generic pickers.

Fonts: `noto-fonts`, `noto-fonts-color-emoji`, `nerd-fonts.symbols-only`, `font-awesome`.

## Verification

```sh
nixfmt modules/home-manager/hyprland/default.nix \
  modules/home-manager/hyprland/hypridle.nix \
  modules/home-manager/hyprland/hyprlock.nix \
  modules/home-manager/hyprland/keybindings.nix \
  modules/home-manager/hyprland/silere.nix \
  modules/home-manager/hyprland/wallpaper.nix \
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
