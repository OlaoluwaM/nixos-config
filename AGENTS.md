# Repository Instructions

## Repository Shape

This is a NixOS/Home Manager flake for `boreas` (NixOS 26.05).

- `flake.nix`: flake inputs, host metadata, NixOS entrypoints, and standalone Home Manager entrypoints.
- `hosts/boreas/`: host-specific NixOS configuration and hardware configuration.
- `home/olaolu/`: user Home Manager profile.
- `modules/nixos/`: reusable NixOS modules.
- `modules/home-manager/`: reusable Home Manager modules.
- `modules/home-manager/hyprland/`: the Hyprland desktop profile. Its `README.md` is the detailed map: keybindings, silere-shell packaging, wallpaper pipeline, lock/idle.
- `pkgs/`: local package definitions/derivations.
- `lib/`: plain Nix functions that both the NixOS and Home Manager sides import (not modules; nothing merges them into `config`).

Change the narrowest module that owns the behavior. Don't push host-specific choices into reusable modules unless the module already takes that host data as an argument.

## Working with the user

Olaolu owns this repo and is still learning Nix and this codebase by making the changes. Work as a mentor and reviewer by default, not as the author.

- **Explain, then point.** Answer with the why, and point at the exact files and lines (`path:line`) and the Nix concepts involved, so Olaolu can read the code directly.
- **Point/Suggest; don't write.** For a change Olaolu wants, either, provide a rough direction and let him figure the rest out or ask questions for the purpose of leading him to the right approach. Don't write code, snippets, or diffs unless explicitly asked to.
- **Edit files only on an explicit request to implement.** Even then, keep the change small, explain what each part does, and hand over the commands that verify it.
- **Review on request.** Check correctness and fit with the surrounding code, explain each problem and why it matters, and leave the fix to Olaolu unless asked to make it.
- **Teach the workflow.** When a check is worth running, give the command and what its output means instead of only reporting a result.
- **Say what you see.** Mentoring doesn't mean holding back: name a real bug or risk plainly, then let Olaolu decide.
- **Leave commits and rebuilds to Olaolu.** Commit only when asked. Never run `nixos-rebuild` or `home-manager switch`; give the exact command to run with `!`.
- **Leave code comments to Olaolu.** Don't add or rewrite comments in this repo; explain changes in your reply instead. If a change makes an existing comment wrong, say so rather than editing it. This doesn't apply to the silere-shell fork, which follows its own `AGENTS.md`.

## The silere-shell Fork

The Hyprland session's shell is **silere-shell**, a Quickshell/QML bar forked from `s3rven/silere-shell`.

- It comes in as the `silere-shell` flake input (`flake = false`) and is packaged in `modules/home-manager/hyprland/modules/silere.nix`. Shell and UI work happens in the checkout at `~/Desktop/dev/silere-shell` (branch `custom-branch`); read its `AGENTS.md` and `README.md` first. After fork commits are pushed, re-lock with `nix flake update silere-shell`.
- **`GeneratedDefaults.qml` is generated** from the `local.hyprland.silere.*` options in `silere.nix`. Change the options or the template, never the packaged file ([adrs/0001](adrs/0001-own-the-forks-defaults-from-nix-instead-of-writing-settings-json.md)).
- Nix-declared defaults must stay inside the fork's `_schema` clamp table (`services/ShellSettings.qml`). The loader clamps out-of-bounds values without saying so.

## Source Of Truth

When prose and code disagree, trust `flake.nix` and the relevant module files over the prose. README files are useful orientation, but they can lag current pins or implementation details.

Don't update `flake.lock`, flake inputs, `home.stateVersion`, or `system.stateVersion` as incidental cleanup. Change them only when the task explicitly calls for it (re-locking `silere-shell` after deliberately pushed fork commits is the routine example), and explain the migration risk.

This repo intentionally runs stable Nixpkgs/Home Manager with selected packages from `nixpkgs-unstable`, plus upstream flakes pinned where Nixpkgs lags (Hyprland, Quickshell, Vicinae). Keep that split unless there's a specific reason to move a whole subsystem together.

## Nix Workflow

Use `nixfmt` for Nix files. Keep module changes close to the existing style: small option sets, explicit imports, and host-specific data flowing through `hostConfig`.

```sh
nix flake check
nix eval .#nixosConfigurations.boreas.config.system.build.toplevel.drvPath  # evaluate only; fast
nix build .#nixosConfigurations.boreas.config.system.build.toplevel --no-link
nix build .#homeConfigurations.olaolu@boreas.activationPackage --no-link
```

Home Manager is built into the NixOS config, so the system build is the check that matches `nixos-rebuild`, for every change. The standalone Home Manager build only matters for `home-manager switch`.

To find out what a setting actually is, evaluate it instead of reading the modules: `nix eval .#nixosConfigurations.boreas.config.<option>` prints the final value after every module has contributed (for example `….config.nix.gc.dates`). Home Manager options sit under `….config.home-manager.users.olaolu.<option>`. Teach Olaolu this when a question is about a value.

## Live Host

Agent sessions run on `boreas` itself, so this config is the running system. Edits change nothing until a rebuild.

- For changes to the compositor, mesa, or anything else the running session holds on to, recommend `nixos-rebuild boot` and a reboot instead of `switch`. Hyprland reloads `hyprland.lua` as soon as Home Manager rewrites it, so a `switch` hands the new config to the old binary.
- Read-only checks against the live session (`hyprctl`, `journalctl --user`, `systemctl --user status`) are fine. Ask before restarting or stopping session units.
- `/etc/nix/nix.conf` and the rest of `/etc` are generated. Change `nix.settings` and the modules instead.

## Hyprland Profile

```text
greetd -> tuigreet -> Hyprland -> hyprland-session.target -> user services
```

- Hyprland starts the target itself. Home Manager's Hyprland systemd integration is deliberately off; read `compositor.nix` and the profile README before changing that.
- Hyprland and its portal come from `lib/hyprland-source.nix`, currently the tag-pinned `hyprland` flake input. The profile README explains the pin, the portal override, and why the system mesa stays on stable. Upgrade by bumping the tag and check that lock, idle, and the shell still work. Don't move a single Hyprland ecosystem package on its own.
- Every chord is defined in `modules/home-manager/hyprland/modules/keybindings.nix`. Keep GNOME and Hyprland bindings on the same chord where practical, and check the other profile before changing one.
- The wallpaper path (`local.hyprland.wallpaper`) is a seeded user-writable file that `wallpaper-set` overwrites in place, not a store symlink. Don't turn it back into an `xdg.configFile` entry.
- Scripts in `modules/home-manager/hyprland/scripts/` are embedded with `pkgs.writeShellApplication`. They start with `# shellcheck shell=bash` and have no shebang.

## Worktree Discipline

Olaolu may have uncommitted changes in this repo or the fork checkout. Never revert, reformat, or fold them into your own work, and check `git status --short` before editing.
