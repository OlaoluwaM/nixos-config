# Hyprland Rice Handoff

This file is a self-contained handoff for continuing the Hyprland/Quickshell rice work in a fresh Codex session.

## Project

- Repository: `/home/olaolu/Desktop/labs/nixos-config`
- User: Olaolu
- Current task: build a minimal but polished Hyprland desktop baseline for the `hyprland` desktop profile.
- Important constraint: do not modify, regenerate, reset, or clean up `flake.lock`; Olaolu handles it manually.

Start a new session by saying:

```text
Read AGENTS.md and HANDOFF.md in /home/olaolu/Desktop/labs/nixos-config, then continue the Hyprland rice work from there.
```

## Required Local Instructions

Read `AGENTS.md` first. It currently says:

- Use the `qt-qml` skill when editing `modules/home-manager/hyprland/quickshell/**/*.qml`, if the skill is available.
- Use the `qt-qml-review` skill before finalizing substantial QML changes, if the skill is available.
- If either skill is missing, ask before installing it from `TheQtCompanyRnD/agent-skills`.
- Prefer the `qt-docs` MCP for Qt/QML API research if it is already configured.
- Ask before configuring the Qt docs MCP globally.

The broader repo/session preferences still apply:

- Use `rg`/`rg --files` for search.
- Use `apply_patch` for manual edits.
- Do not revert user changes.
- Keep edits scoped.
- For current docs or explicit research, verify with sources.
- Use `defuddle parse <url> --md` for web page extraction where useful.

## Product Direction

The desired desktop is a minimal baseline, not a copied rice:

- Look and feel inspired primarily by `ilyamiro/nixos-configuration`.
- Some baseline expectations inspired by HyDE, but stripped down heavily.
- Catppuccin Mocha only.
- Top bar should float with padding.
- Prefer icons over text in the top bar.
- App launcher should be bound to `Super`, not shown as a bar button.
- Workspace indicator should be dynamic like GNOME: show active/occupied workspaces only.
- Center clock should show month, day, and 12-hour time.
- Calendar popover should be GNOME-like and navigable forward/backward by month.
- Fixed extra timezones:
  - Birmingham, UK
  - Lagos, Nigeria
  - San Francisco, CA
- Quick settings should behave like GNOME quick settings and be bound to `Super+Q`.
- Quick settings should cover volume, built-in backlight brightness, network/VPN, Bluetooth, DND, power profile, battery, system stats, and power menu access.
- CPU load, memory usage, and system temperature should be visible at all times in the bar.
- Do not include broad GTK/Qt theming yet.
- Do not include SDDM theming; the profile uses `greetd`/`tuigreet`.
- Do not use UWSM yet.
- Keep `swww` for wallpapers, not `hyprpaper`.
- Use Nautilus as file manager plus `udiskie` for removable media mounting.

## Current Relevant Files

- `AGENTS.md`: repo-local QML skill/MCP instructions.
- `HANDOFF.md`: this file.
- `modules/home-manager/hyprland/default.nix`: Home Manager baseline packages, portals, fonts, Nautilus, udiskie, Qt/QML IDE support.
- `modules/home-manager/hyprland/quickshell.nix`: Hyprland config, Quickshell deployment, systemd user services, keybinds, script packaging.
- `modules/home-manager/hyprland/quickshell/shell.qml`: Quickshell bar, popovers, notifications, tray.
- `modules/home-manager/hyprland/scripts/hypr-shell-status.sh`: JSON status for bar/quick settings.
- `modules/home-manager/hyprland/scripts/hypr-shell-timezones.sh`: clock/calendar/timezone JSON.
- `modules/home-manager/hyprland/scripts/hypr-shell-popup.sh`: helper for toggling Quickshell popovers from Hyprland binds.
- `modules/home-manager/hyprland/README.md`: usage guide, references, verification notes.

## Current Git/Worktree Caveat

The worktree may be dirty. At the time this handoff was written, expected changes included:

- `AGENTS.md` added.
- `HANDOFF.md` added.
- `modules/home-manager/hyprland/README.md` modified.
- `modules/home-manager/hyprland/default.nix` modified.
- `modules/home-manager/hyprland/quickshell.nix` modified.
- `modules/home-manager/hyprland/quickshell/shell.qml` modified.
- `modules/home-manager/hyprland/scripts/hypr-shell-status.sh` modified.
- `modules/home-manager/hyprland/scripts/hypr-shell-timezones.sh` modified.
- `modules/home-manager/hyprland/scripts/hypr-shell-popup.sh` added.
- `flake.lock` may show as added/changed due earlier checks; leave it alone.

Do not assume every dirty file was changed by the current agent. Inspect before editing.

## Implemented So Far

Quickshell / bar:

- Runtime installed through Nixpkgs `quickshell` in Home Manager.
- Quickshell runs as `quickshell --config hyprland`.
- QML is installed to `~/.config/quickshell/hyprland/shell.qml`.
- Floating top bar implemented via Quickshell.
- Launcher button removed from bar.
- Dynamic workspace pills implemented using `Quickshell.Hyprland`.
- Center date/time changed to month/day/12-hour style.
- Calendar popover supports previous/next month navigation.
- Fixed timezones included through helper script.
- Quick settings popover added and bound to `Super+Q`.
- System tray overflow added.
- Native Quickshell notifications used instead of swaync/dunst/mako/fnott.

Bindings:

- `Super` and `Super+Space` use `vicinae open`.
- Clipboard history uses a Vicinae deeplink.
- `Super+Q` toggles Quickshell quick settings.
- `F6` screenshot workflow uses grim/slurp/satty/wl-clipboard.
- `Super+E` opens Nautilus.
- `Super+N` opens NetworkManager connection editor.
- `Super+B` opens Blueman manager.
- `Super+M` opens Mission Center.
- `Super+Escape` and `XF86PowerOff` open `hyprshutdown`.

Packages/services:

- `swww` wallpaper flow retained.
- `hyprpaper` deliberately removed/excluded.
- `hyprsunset` included for night light.
- `hyprpolkitagent` included.
- `hyprshutdown` included from the unstable track.
- `udiskie` added for USB/removable media mounting.
- `qt.enable = true` added for QML import paths.
- `qt6.qtdeclarative` added for `qmlls`.
- `qt6.qtsvg` and `qt6.qtimageformats` added for QML image support.

README:

- Usage guide added/expanded.
- Verification section added.
- “Updating To Unstable” section added.
- QML IDE Integration section added.
- Sources/references added, including the NotebookLM notebook and Qt QML skill repo.

NotebookLM:

- Notebook: `Quickshell Hyprland Rice Reference`
- URL: `https://notebooklm.google.com/notebook/3976ddbc-f445-4d0d-b98b-7a15800809a7`
- It contains Quickshell, Qt/QML, Hyprland, Vicinae, ilyamiro, screenshot, and Qt agent-skills references.

## Pending Skill/MCP Setup

The Qt QML skills were not installed when this handoff was written. The Qt docs MCP was also not configured.

To install the skills, ask Olaolu for approval first, then run:

```sh
python /home/olaolu/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo TheQtCompanyRnD/agent-skills \
  --path skills/qt-qml \
  --path skills/qt-qml-review
```

After installation, restart Codex so the new skills are loaded.

The Qt documentation MCP endpoint is:

```text
https://qt-docs-mcp.qt.io/mcp
```

Configuring it changes the local Codex environment, not this repo. Ask before doing it.

## Verification Already Done Previously

Earlier validation during this task included:

- `nixfmt` on touched Nix files.
- `shfmt` and `shellcheck` on shell scripts.
- Temporary Home Manager build with `desktopProfile = "hyprland"`.
- Temporary NixOS toplevel build.
- `Hyprland --verify-config --config <rendered hyprland.conf>` returned `config ok`.
- `hypr-shell-status` emitted valid JSON under a temporary runtime dir.
- Binding commands were audited; Vicinae launcher corrected to `vicinae open`.

Most recent checks after adding Qt/QML IDE support:

- `nixfmt --check modules/home-manager/hyprland/default.nix`
- `git diff --check -- modules/home-manager/hyprland/default.nix modules/home-manager/hyprland/README.md`
- `nix-instantiate --parse modules/home-manager/hyprland/default.nix`

Full Quickshell runtime behavior still needs live Hyprland session testing, especially:

- Quick settings toggle via `Super+Q`.
- Calendar navigation.
- System tray menu behavior.
- Notification actions.
- Power button / `hyprshutdown`.
- Brightness control against the built-in backlight.
- Power profile cycling.

## Useful Sources

- Quickshell install/editor setup: `https://quickshell.org/docs/v0.1.0/guide/install-setup/`
- Quickshell docs: `https://quickshell.org/docs/`
- Qt QML reference: `https://doc.qt.io/qt-6/qmlreference.html`
- Qt `qmlls`: `https://doc.qt.io/qt-6/qtqml-tooling-qmlls.html`
- Qt agent-skills repo: `https://github.com/TheQtCompanyRnD/agent-skills`
- Qt docs MCP README: `https://github.com/TheQtCompanyRnD/agent-skills/blob/main/mcp/qt-documentation-mcp/README.md`
- ilyamiro config: `https://github.com/ilyamiro/nixos-configuration`
- ilyamiro preview: `https://github.com/ilyamiro/nixos-configuration/blob/master/previews/screenshot1.png`
- Hyprland useful utilities: `https://wiki.hypr.land/Useful-Utilities/`
- Hyprland must-have utilities: `https://wiki.hypr.land/Useful-Utilities/Must-have/`
- Hyprland binds: `https://wiki.hypr.land/Configuring/Binds/`
- Hyprland NVIDIA notes: `https://wiki.hypr.land/Nvidia/`
- Vicinae deeplinks: `https://docs.vicinae.com/deeplinks`

## Recommended Next Steps

1. Read `AGENTS.md` and this handoff.
2. Check `git status --short --untracked-files=all`.
3. Leave `flake.lock` untouched.
4. Install `qt-qml` and `qt-qml-review` only if Olaolu approves.
5. Configure Qt docs MCP only if Olaolu approves.
6. Restart Codex after skill/MCP setup.
7. Use the QML skill/review workflow for future `shell.qml` changes.
8. Continue live-session validation of the Quickshell UI.
