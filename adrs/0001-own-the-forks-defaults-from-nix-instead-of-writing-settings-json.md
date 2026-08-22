# ADR 0001: Own the Fork's Defaults from Nix Instead of Writing settings.json

- **Status:** Accepted
- **Date:** 2026-08-12

## Context

The Caffyne shell is being replaced by a fork of silere-shell
(Quickshell/QML). Caffyne's configuration is runtime-owned: the shell writes
and rewrites its own config files, so making any of it declarative required
`caffyne.nix` to grow ~1,520 lines of activation-time reconciliation —
seeding, patching, and guarding files that two parties (Nix and the running
shell) both believed they owned. Retiring that machinery is a primary
motivation for the migration.

The replacement must still satisfy two pulls in tension: the user wants a
curated set of look-and-feel settings pinned declaratively (bar geometry,
theme mode, fonts), while the in-shell Settings UI must keep working for
everything else — hybrid ownership was decided early and is not in question.
The question was the *mechanism*.

silere-shell's settings store (`services/ShellSettings.qml`) has three
documented semantics that shape the option space: it persists **only
non-default values** to `$XDG_CONFIG_HOME/silere-shell/settings.json`; it
type-checks and range-clamps every value on load against a typed spec table;
and it leaves a file it cannot parse alone rather than overwriting it.
"Default" means whatever the QML property initializer evaluates to.

Options considered:

1. **Nix writes `settings.json`** (Home Manager file or activation script).
   Rejected: the shell also writes that file, recreating exactly the
   two-owners-one-file contention that made `caffyne.nix` large — plus
   Home Manager symlinks it read-only, breaking the Settings UI outright.
2. **Nix writes a second config layered at runtime.** Rejected: silere has
   no layering concept; building one is a large behavioral fork.
3. **Nix substitutes the fork's *defaults*** via a generated singleton
   (`GeneratedDefaults.qml`) that the `ShellSettings` property initializers
   read, mirroring the existing `GeneratedTheme.qml` pattern in
   `modules/home-manager/hyprland/quickshell.nix`. Chosen.

## Decision

Nix owns the fork's compiled-in defaults, not its settings file. The fork
gains one commit: a `config/GeneratedDefaults.qml` singleton carrying
upstream-identical values, with `services/ShellSettings.qml` initializers
pointed at it. The Nix module renders that file from `local.hyprland.silere.*`
options at build time. `settings.json` remains exclusively the Settings UI's:
Nix never reads, writes, seeds, or reconciles it.

Because the shell persists only non-default values, the two owners have
disjoint territory by construction: a declared option change arrives as a new
default on rebuild; a user override in the Settings UI is a non-default value
that survives rebuilds and wins for its key. There is no activation-time
reconciliation step at all.

Declared defaults must respect the spec table's min/max/enum bounds in
`ShellSettings.qml`, or the loader clamps them silently.

## Consequences

**Positive**

- The Nix module stays small: it renders one QML file, replacing the ~1,520
  lines of seed/patch/guard logic the same requirement cost under Caffyne.
- No file is ever contended: Nix owns a store path, the shell owns
  `settings.json`, and neither party touches the other's.
- The Settings UI keeps full upstream behavior — no read-only symlink, no
  "managed by Nix, do not edit" split-brain.
- Rollback semantics are clean: `settings.json` is inert data that no Nix
  generation depends on or invalidates.

**Negative / trade-offs**

- A Nix default change is invisible for any key the user has ever overridden
  in the Settings UI — the override, being a non-default value, wins
  silently. This is correct hybrid behavior but can read as "my option
  didn't apply"; the migration plan's Phase 3 exit criterion exercises it
  deliberately.
- The mechanism requires forking: upstream silere-shell has no defaults
  hook, so the `GeneratedDefaults.qml` commit is permanent fork divergence
  that must survive every upstream merge.
- "Default" is now a build-time value, so auditing effective shell state
  requires looking in two places: the generated singleton and
  `settings.json`.
- The guarantee leans on upstream's only-write-non-defaults semantics; if a
  future upstream change starts persisting all values, the disjointness
  breaks and this ADR must be revisited.

## Related

- This is the first ADR in this repository, promoted from the Silere
  migration session notes (written 2026-08-12) once the migration completed.
- The fork side of the contract is enforced by the gates in the fork
  checkout's `AGENTS.md`.
