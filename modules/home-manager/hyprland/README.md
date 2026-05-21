# Minimal Hyprland Rice

This module is a small Hyprland baseline for the `hyprland` desktop profile. It is intentionally not a copied full rice. The goal is a Catppuccin Mocha desktop shell with the basics wired up cleanly: a top bar, launcher, notifications, tray, lock screen, idle handling, wallpapers, screenshots, removable media, and the common Wayland desktop plumbing.

## Entry Points

- `modules/nixos/hyprland.nix`: system-level Hyprland, greetd/tuigreet, PAM, dconf, GVfs, and UDisks.
- `modules/home-manager/hyprland/default.nix`: Home Manager package baseline, portals, fonts, Nautilus, and udiskie.
- `modules/home-manager/hyprland/quickshell.nix`: Hyprland config, Quickshell deployment, session services, keybinds, and small helper scripts.
- `modules/home-manager/hyprland/quickshell/shell.qml`: the Quickshell bar, popovers, native notifications, and tray.
- `modules/home-manager/hyprland/hyprlock.nix`: lock screen.
- `modules/home-manager/hyprland/hypridle.nix`: idle lock and display-off behavior.
- `modules/home-manager/hyprland/scripts/`: status, timezone, wallpaper, and screenshot helpers.

Enable the profile by setting the host `desktopProfile` to `"hyprland"` in `flake.nix`.

## Desktop Shape

The session starts from `greetd` using `tuigreet --cmd Hyprland`. The setup deliberately avoids UWSM for now, so the generated `hyprland.conf` explicitly starts the user services that the session depends on:

- `hypr-shell-swww.service`
- `hypr-shell-wallpaper.service`
- `hypr-shell-quickshell.service`
- `hypr-shell-vicinae.service`
- `hypr-shell-clipboard.service`
- `hypridle.service`
- `hyprpolkitagent.service`
- `hyprsunset.service`
- `udiskie.service`

This explicit startup is intentional. Several Home Manager services are linked to `graphical-session.target`, but this profile does not currently rely on UWSM to activate that target.

## Top Bar

Quickshell runs as `quickshell --config hyprland` and loads `~/.config/quickshell/hyprland/shell.qml`.

The bar is top-aligned and includes:

- Vicinae launcher button.
- Workspace labels for workspaces 1 through 5.
- Center clock.
- GNOME-like calendar popover with fixed extra zones:
  - Birmingham, UK
  - Lagos, Nigeria
  - San Francisco, CA
- MPRIS/media status and basic media controls.
- Always-visible CPU, memory, and temperature readouts.
- Current power profile; clicking cycles the profile.
- Network and VPN status; clicking opens `nm-connection-editor`.
- Bluetooth status; clicking opens `blueman-manager`.
- Battery state.
- DND toggle for Quickshell notifications.
- Native Quickshell notification history and popups.
- System tray overflow, shown only when tray items exist.
- Power button wired to `hyprshutdown`.

The tray uses Quickshell's StatusNotifier support. It is for modern AppIndicator/StatusNotifier tray items, not legacy XEmbed tray icons.

## Keybinds

| Binding | Action |
| --- | --- |
| `Super` | Open Vicinae launcher |
| `Super+Space` | Open Vicinae launcher fallback |
| `Super+Return` | Open Kitty |
| `Super+Shift+V` | Open Vicinae clipboard history |
| `Super+Shift+W` | Pick a random wallpaper from `$WALLPAPERS_DIR` |
| `F6` | Region screenshot, then annotate/copy/save in Satty |
| `Shift+F6` | Full screenshot, then annotate/copy/save in Satty |
| `Ctrl+F6` | Active-window screenshot, then annotate/copy/save in Satty |
| `Super+E` | Open Nautilus |
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

## Wallpapers

Wallpapers come from the directory referenced by `$WALLPAPERS_DIR`. The dotfiles module currently sets that to `~/Pictures/Wallpapers`.

The wallpaper helper:

- supports `.jpg`, `.jpeg`, `.png`, and `.webp`;
- stores the selected wallpaper path in `$XDG_STATE_HOME/hypr-shell/wallpaper`;
- maintains `$XDG_CACHE_HOME/hypr-shell/lock-wallpaper` for hyprlock;
- applies wallpapers with `swww`.

Useful commands:

```sh
hypr-shell-wallpaper random
hypr-shell-wallpaper restore
hypr-shell-wallpaper set /path/to/image.png
```

## Screenshots

The screenshot workflow uses `grim`, `slurp`, `wl-clipboard`, and Satty.

Screenshots are piped into Satty for annotation. Pressing Enter copies the edited image to the clipboard and also saves it under:

```text
~/Pictures/Screenshots/
```

The selection UI uses Catppuccin-ish colors to match the shell.

## Lock And Idle

`hypridle` handles idle behavior:

- after 15 minutes, lock the session;
- after 20 minutes, turn displays off;
- on resume, turn displays back on;
- before sleep, lock the session.

`hyprlock` uses the current wallpaper symlink as its background, with blur, a centered password field, and time/date labels. NixOS defines `security.pam.services.hyprlock = { };` so hyprlock can authenticate.

## Power Profiles

The bar shows the current power profile as `PWR <profile>`.

The widget is intentionally backend-generic:

- primary backend: `powerprofilesctl`, provided by `power-profiles-daemon`;
- fallback backend: `asusctl`, only if the command is already available and the generic backend cannot be used.

This keeps Quickshell decoupled from host-specific ASUS policy. On Boreas, the system profile already enables `power-profiles-daemon` and `asusd`, with ASUS power behavior defined in `hosts/boreas/default.nix`.

Useful commands:

```sh
hypr-shell-power-profile status
hypr-shell-power-profile cycle
powerprofilesctl get
powerprofilesctl list
```

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

## Deliberate Exclusions

These are intentionally not part of this baseline:

- `hyprpaper`: replaced by `swww`.
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

- Hyprland must-have utilities: https://wiki.hypr.land/Useful-Utilities/Must-have/
- Hyprland screenshots and recording: https://wiki.hypr.land/Useful-Utilities/Screenshots-and-Recording/
- Hyprland wallpapers: https://wiki.hypr.land/Useful-Utilities/Wallpapers/
- Hyprland clipboard managers: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/
- Hyprland xdg-desktop-portal-hyprland: https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/
- Hyprland hypridle: https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
- Hyprland hyprlock: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
- Hyprland hyprsunset: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
- Hyprland hyprpolkitagent: https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/
- Hyprland NVIDIA notes: https://wiki.hypr.land/Nvidia/
- Quickshell SystemTray: https://quickshell.org/docs/v0.1.0/types/Quickshell.Services.SystemTray/SystemTray/
- Quickshell SystemTrayItem: https://quickshell.org/docs/v0.1.0/types/Quickshell.Services.SystemTray/SystemTrayItem/
