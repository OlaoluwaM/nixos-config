# Minimal Hyprland Rice

This module is the `hyprland` desktop profile. It is currently **stock
Hyprland**: compositor config, keybinds, hyprlock, hypridle, hyprsunset,
Vicinae, portals, and a few helper scripts. There is no bar and no shell UI
right now -- the previous desktop shell stack was torn down as a clean slate,
and a new `silere-shell` integration is in progress on this branch.

## Entry Points

- `modules/nixos/hyprland.nix`: system-level Hyprland, greetd/tuigreet, PAM, dconf, GVfs, and UDisks.
- `modules/home-manager/hyprland/default.nix`: Home Manager Hyprland config, `hyprland-session.target`, keybinds, portals, wallpaper/session plumbing, shared packages, fonts, Nautilus, and udiskie.
- `modules/home-manager/hyprland/hyprlock.nix`: lock screen.
- `modules/home-manager/hyprland/hypridle.nix`: idle lock and display-off behavior.
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
`vicinae.service`, `hypr-shell-media-idle-inhibit.service`,
`hypr-shell-caffeine.service`, `hypridle.service`, `hyprpolkitagent.service`,
`hyprsunset.service`, `udiskie.service`.

The setup deliberately avoids UWSM.

## Keybinds

See `./default.nix`. Hardware media/brightness keys (volume, brightness,
keyboard backlight) are bound directly to `wpctl`/`brightnessctl` since there
is no shell OSD to own them. A handful of chords that used to open shell
surfaces (wallpaper picker, settings, wifi, bluetooth, session menu) are
intentionally unbound until the new shell lands.

## Helper Scripts

Scripts under `scripts/` are **not** standalone executables; the Home Manager
modules read them with `builtins.readFile` and embed them into
`pkgs.writeShellApplication`, which supplies the shebang, `set -euo pipefail`,
and `runtimeInputs` PATH. Each script starts with `# shellcheck shell=bash`
and omits its own shebang/`set` line for that reason.

- `hypr-shell-screenshot`: grim/slurp/Satty, saves to `~/Pictures/Screenshots/`.
- `hypr-shell-record`: wf-recorder, saves to `~/Videos/Screencasts/`.
- `hypr-shell-caffeine`: manual systemd idle inhibitor toggle.

## Lock, Idle, And Wallpaper

`hypridle` locks the session after 15 minutes idle or before sleep, honoring
`hypr-shell-media-idle-inhibit.service` (PipeWire playback) and
`hypr-shell-caffeine.service` (manual toggle).

`hyprlock`'s background is `local.hyprland.wallpaper`, a stable Nix-owned path
shared across the session. It currently points at a bundled `nixos-artwork`
wallpaper as an interim placeholder, since hyprlock needs a real image at that
path even on first boot before any wallpaper picker exists. A real wallpaper
pipeline is future work.

## Portals And Fonts

Portals: `xdg-desktop-portal-hyprland` (from Home Manager's Hyprland module)
plus `xdg-desktop-portal-gtk` as the fallback for generic pickers.

Fonts: `noto-fonts`, `noto-fonts-color-emoji`, `nerd-fonts.symbols-only`, `font-awesome`.

## Verification

```sh
nixfmt modules/home-manager/hyprland/default.nix \
  modules/home-manager/hyprland/hypridle.nix \
  modules/home-manager/hyprland/hyprlock.nix \
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
