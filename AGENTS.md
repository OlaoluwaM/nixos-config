# Repository Instructions

## Repository Shape

This is a NixOS/Home Manager flake for the `boreas` (and other) machine.

- `flake.nix`: flake inputs, host metadata, NixOS entrypoints, and standalone Home Manager entrypoints.
- `hosts/boreas/`: host-specific NixOS configuration and hardware configuration.
- `home/olaolu/`: user Home Manager profile.
- `modules/nixos/`: reusable NixOS modules.
- `modules/home-manager/`: reusable Home Manager modules.
- `modules/home-manager/hyprland/`: Hyprland desktop profile (its `README.md` is the detailed map: keybindings, silere-shell packaging, wallpaper pipeline, lock/idle).
- `pkgs/`: local package definitions.

Prefer changing the narrowest module that owns the behavior. Do not push host-specific choices into reusable modules unless the module already takes that host data as an argument.

## The silere-shell Fork

The Hyprland session's shell is **silere-shell**, a Quickshell/QML bar maintained as a fork of `s3rven/silere-shell`:

- Consumed as the `silere-shell` flake input — `github:OlaoluwaM/silere-shell/custom-branch` with `flake = false`. It is a plain pinned source tree; packaging happens here, in `modules/home-manager/hyprland/silere.nix`. The fork ships a dev-shell-only `flake.nix` for hacking on it; it must never grow `packages`/overlay outputs, because the build-time defaults substitution needs configuration knowledge only this repo has.
- The local checkout lives at `~/Desktop/dev/silere-shell`, branch `custom-branch`. Shell/UI work happens **there**, not in this repo. After pushing fork commits, re-lock deliberately with `nix flake update silere-shell`.
- **GeneratedDefaults.qml is generated output.** In the built package it is rendered from the `local.hyprland.silere.*` options in `silere.nix` — change the options or the render template, never the packaged file. In the fork, the checked-in copy holds upstream-identical defaults so non-Nix users see no change; keep that invariant.
- Nix-declared default values must stay inside the fork's `_schema` clamp table (`services/ShellSettings.qml`) — the loader silently clamps out-of-bounds values.

Fork working conventions (from the fork's `docs/forking.md`, plus this project's):

- For all UI work, first inspect and follow the shell's existing design system and visual conventions; prefer its established components and patterns over new one-off styles.
- Commit style matches upstream: short, lowercase, imperative subjects. Keep commits small and mechanical — every line of divergence is future rebase cost.
- Gates before pushing: `bash scripts/ci-lint.sh` and `bash scripts/check.sh` (run inside the fork's `nix develop` so `qs`/`hyprctl` resolve).
- Every new QML file needs a `qmldir` entry; motion goes through the `Motion`/`MotionBehavior` tokens (never bare `Behavior`); row heights via `Metrics.rowHeightFor()`; colors only from `Theme` tokens — no hex in widgets. The lint scripts enforce these.
- Keep the `silere-*` layer-shell namespaces: Hyprland blur/animation rules match those strings.
- Use the `qt-qml` skill when editing QML; run `qt-qml-review` before finalizing substantial QML changes. For Qt/QML API research prefer the `qt-docs` MCP server (`https://qt-docs-mcp.qt.io/mcp`) if configured; otherwise official Qt and Quickshell documentation. Ask before configuring the MCP server globally, because that changes the local agent environment rather than this repository.

## Source Of Truth

Trust `flake.nix` and the relevant module files over older prose when there is a conflict. README files are useful orientation, but they may lag current pins or implementation details.

Do not update `flake.lock`, flake inputs, `home.stateVersion`, or `system.stateVersion` as incidental cleanup. Change them only when the task explicitly calls for it (re-locking `silere-shell` after deliberately pushed fork commits is the routine example), and explain the migration risk.

This repo intentionally uses stable Nixpkgs/Home Manager with selected packages from `nixpkgs-unstable`. Preserve that split unless there is a specific reason to move a whole subsystem together.

## Nix Workflow

Use `nixfmt` for Nix files. Keep module changes idiomatic and close to existing style: small option sets, explicit imports, and host-specific data flowing through `hostConfig`.

Useful verification commands, depending on the change:

```sh
nix flake check
nix eval .#nixosConfigurations.boreas.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.boreas.config.system.build.toplevel --no-link
nix build .#homeConfigurations.olaolu@boreas.activationPackage --no-link
```

For Home Manager-only changes, at least evaluate or build `.#homeConfigurations.olaolu@boreas.activationPackage` when feasible. For NixOS module changes, evaluate or build the `boreas` system derivation when feasible.

**Never run `nixos-rebuild switch` or `home-manager switch` unprompted.** The user's daily driver is Fedora; nothing here is live on this host. Runtime verification happens when the user boots their separate NixOS installation on its own SSD — build-level checks are the ceiling for agent verification.

## Hyprland Profile

The Hyprland profile is intentionally a small, owned desktop setup rather than a copied rice. Keep changes aligned with the existing launch path:

```text
greetd -> tuigreet -> Hyprland -> Home Manager hyprland.lua -> hyprland-session.target -> user services
```

`hyprland-session.target` starts `silere-shell.service`, Vicinae, the awww wallpaper daemon and restore unit, hypridle, hyprsunset, and the idle-inhibit helpers — see the profile README for the full list.

Do not casually switch only one Hyprland ecosystem package to unstable. If Hyprland itself moves, verify the compositor, portal, lock, idle, and shell stack coherently.

Keybindings live in `modules/home-manager/hyprland/keybindings.nix` — the single definition site for every chord. Keep equivalent GNOME and Hyprland keybindings on the same chord wherever practical; before changing a binding in either profile, inspect the other profile and preserve parity unless a desktop-specific constraint requires an intentional difference.

The stable wallpaper path (`local.hyprland.wallpaper`) is a **seeded user-writable file**, not a store symlink — `wallpaper-set` overwrites it in place. Do not convert it back to an `xdg.configFile` entry.

Helper scripts under `modules/home-manager/hyprland/scripts/` are embedded with `pkgs.writeShellApplication`. Preserve the existing convention: scripts use `# shellcheck shell=bash` and omit a direct shebang.

## Worktree Discipline

This applies to both this repo and the fork checkout. The worktree may contain unrelated user changes. Do not revert, reformat, or fold them into your work unless the task explicitly requires it.

Before editing, check `git status --short`. Before finalizing, show or inspect the relevant diff. Keep commits atomic if Olaolu asks for a commit.
