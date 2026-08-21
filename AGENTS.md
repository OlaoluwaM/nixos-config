# Repository Instructions

## Repository Shape

This is a NixOS/Home Manager flake for the `boreas` (and other) machine.

- `flake.nix`: flake inputs, host metadata, NixOS entrypoints, and standalone Home Manager entrypoints.
- `hosts/boreas/`: host-specific NixOS configuration and hardware configuration.
- `home/olaolu/`: user Home Manager profile.
- `modules/nixos/`: reusable NixOS modules.
- `modules/home-manager/`: reusable Home Manager modules.
- `modules/home-manager/hyprland/`: the Hyprland desktop profile. Its `README.md` is the detailed map: keybindings, silere-shell packaging, wallpaper pipeline, lock/idle.
- `pkgs/`: local package definitions.

Change the narrowest module that owns the behavior. Don't push host-specific choices into reusable modules unless the module already takes that host data as an argument.

## The silere-shell Fork

The Hyprland session's shell is **silere-shell**, a Quickshell/QML bar maintained as a fork of `s3rven/silere-shell`:

- It comes in as the `silere-shell` flake input: `github:OlaoluwaM/silere-shell/custom-branch` with `flake = false`, meaning a plain pinned source tree. Packaging happens here, in `modules/home-manager/hyprland/modules/silere.nix`. The fork ships a `flake.nix` that only provides a dev shell; it must never grow `packages` or overlay outputs, because substituting the build-time defaults needs configuration knowledge only this repo has.
- The local checkout lives at `~/Desktop/dev/silere-shell`, branch `custom-branch`. Shell and UI work happens **there**, not in this repo. After fork commits are pushed, re-lock deliberately with `nix flake update silere-shell`.
- **GeneratedDefaults.qml is generated output.** In the built package it is rendered from the `local.hyprland.silere.*` options in `silere.nix`. Change the options or the render template, never the packaged file. The reasoning behind this mechanism is in [adrs/0001](adrs/0001-own-the-forks-defaults-from-nix-instead-of-writing-settings-json.md).
- Nix-declared default values must stay inside the fork's `_schema` clamp table (`services/ShellSettings.qml`). The loader clamps out-of-bounds values without saying so.

Fork working conventions (commit style, pre-commit gates including the settings contract between `GeneratedDefaults.qml` and the silere module's render, QML rules, and the upstream merge policy) live in the fork checkout's `AGENTS.md` and `README.md`. Read them there before fork work; don't restate them here.

## Source Of Truth

When prose and code disagree, trust `flake.nix` and the relevant module files over the prose. README files are useful orientation, but they can lag current pins or implementation details.

Don't update `flake.lock`, flake inputs, `home.stateVersion`, or `system.stateVersion` as incidental cleanup. Change them only when the task explicitly calls for it (re-locking `silere-shell` after deliberately pushed fork commits is the routine example), and explain the migration risk.

This repo intentionally runs stable Nixpkgs/Home Manager with selected packages from `nixpkgs-unstable`. Keep that split unless there's a specific reason to move a whole subsystem together.

## Nix Workflow

Use `nixfmt` for Nix files. Keep module changes idiomatic and close to the existing style: small option sets, explicit imports, and host-specific data flowing through `hostConfig`.

Useful verification commands, depending on the change:

```sh
nix flake check
nix eval .#nixosConfigurations.boreas.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.boreas.config.system.build.toplevel --no-link
nix build .#homeConfigurations.olaolu@boreas.activationPackage --no-link
```

For Home Manager-only changes, at least evaluate or build `.#homeConfigurations.olaolu@boreas.activationPackage` when feasible. For NixOS module changes, evaluate or build the `boreas` system derivation when feasible.

**Never run `nixos-rebuild switch` or `home-manager switch` unprompted.** The user's daily driver is Fedora; nothing here is live on this host. Runtime verification happens when the user boots their separate NixOS installation on its own SSD, so build-level checks are the ceiling for agent verification.

## Hyprland Profile

The Hyprland profile is deliberately a small, owned desktop setup rather than a copied rice. Keep changes aligned with the existing launch path:

```text
greetd -> tuigreet -> Hyprland -> Home Manager hyprland.lua -> hyprland-session.target -> user services
```

`hyprland-session.target` starts `silere-shell.service`, Vicinae, the awww wallpaper daemon and restore unit, hypridle, hyprsunset, and the idle-inhibit helpers. The profile README has the full list.

Don't casually switch just one Hyprland ecosystem package to unstable. If Hyprland itself moves, verify that the compositor, portal, lock, idle, and shell stack move coherently.

Keybindings live in `modules/home-manager/hyprland/modules/keybindings.nix`, the single definition site for every chord. Keep equivalent GNOME and Hyprland keybindings on the same chord wherever practical. Before changing a binding in either profile, inspect the other profile and preserve parity unless a desktop-specific constraint requires an intentional difference.

The stable wallpaper path (`local.hyprland.wallpaper`) is a **seeded user-writable file**, not a store symlink; `wallpaper-set` overwrites it in place. Don't convert it back to an `xdg.configFile` entry.

Helper scripts under `modules/home-manager/hyprland/scripts/` are embedded with `pkgs.writeShellApplication`. Keep the existing convention: scripts use `# shellcheck shell=bash` and omit a direct shebang.

## Worktree Discipline

This applies to both this repo and the fork checkout. The worktree may contain unrelated user changes. Don't revert, reformat, or fold them into your work unless the task explicitly requires it.

Before editing, check `git status --short`. Before finalizing, show or inspect the relevant diff. Keep commits atomic if Olaolu asks for a commit.
