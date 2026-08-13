# Repository Instructions

## Repository Shape

This is a NixOS/Home Manager flake for the `boreas` (and other) machine.

- `flake.nix`: flake inputs, host metadata, NixOS entrypoints, and standalone Home Manager entrypoints.
- `hosts/boreas/`: host-specific NixOS configuration and hardware configuration.
- `home/olaolu/`: user Home Manager profile.
- `modules/nixos/`: reusable NixOS modules.
- `modules/home-manager/`: reusable Home Manager modules.
- `modules/home-manager/hyprland/`: Hyprland desktop profile.
- `pkgs/`: local package definitions.

Prefer changing the narrowest module that owns the behavior. Do not push host-specific choices into reusable modules unless the module already takes that host data as an argument.

## Source Of Truth

Trust `flake.nix` and the relevant module files over older prose when there is a conflict. README files are useful orientation, but they may lag current pins or implementation details.

Do not update `flake.lock`, flake inputs, `home.stateVersion`, or `system.stateVersion` as incidental cleanup. Change them only when the task explicitly calls for it, and explain the migration risk.

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

Do not run `nixos-rebuild switch` or `home-manager switch` unless Olaolu explicitly asks for a live system activation.

## Existing Design System

For all UI work in this repo, first inspect and follow the existing design system and local visual conventions. Prefer established components, spacing, typography, colors, interaction patterns, icons, and file organization over introducing new one-off styles.

## Hyprland Profile

The Hyprland profile is intentionally a small, owned desktop setup rather than a copied rice. Keep changes aligned with the existing launch path:

```text
greetd -> tuigreet -> Hyprland -> Home Manager hyprland.conf -> hyprland-session.target -> user services
```

Do not casually switch only one Hyprland ecosystem package to unstable. If Hyprland itself moves, verify the compositor, portal, lock, idle, and shell stack coherently.

Keep equivalent GNOME and Hyprland keybindings on the same chord wherever practical. Before changing a binding in either profile, inspect the other profile and preserve parity unless a desktop-specific constraint requires an intentional difference.

Helper scripts under `modules/home-manager/hyprland/scripts/` are embedded with `pkgs.writeShellApplication`. Preserve the existing convention: scripts use `# shellcheck shell=bash` and omit a direct shebang.

## Qt Documentation MCP

When researching Qt or QML APIs for Quickshell work, prefer the `qt-docs` MCP server if it is already configured. It provides Qt documentation lookup through:

- `https://qt-docs-mcp.qt.io/mcp`

If the MCP server is not configured, fall back to official Qt and Quickshell documentation. Ask the user before configuring the MCP server globally, because that changes the local agent environment rather than this repository.

## Worktree Discipline

The worktree may contain unrelated user changes. Do not revert, reformat, or fold them into your work unless the task explicitly requires it.

Before editing, check `git status --short`. Before finalizing, show or inspect the relevant diff. Keep commits atomic if Olaolu asks for a commit.
