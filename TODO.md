# TODO

## Hyprland: off the flake

`lib/hyprland-source.nix` picks where Hyprland comes from; switching is a one-word change to its last line. Hyprland needs 0.57+ and its portal 1.5.0+ (workspace sharing) in whichever source you pick. Check with `nix eval --raw github:nixos/nixpkgs/<channel>#hyprland.version` and `#xdg-desktop-portal-hyprland.version`.

- [ ] Move to `unstable` once nixos-unstable has both. Patch releases then arrive with `nix flake update nixpkgs-unstable`, with no tag bumps.
- [ ] Move to stable nixpkgs once a stable release has both (likely 26.11).
- [ ] Once nothing uses the flake: delete the `hyprland` input from `flake.nix`, the `hyprland.cachix.org` entries in `hosts/boreas/default.nix`, and the flake wording in the profile README and `AGENTS.md`.
- [ ] At the 26.11 upgrade, if Hyprland still comes from the flake or `unstable`: before rebooting, check that the mesa driver doesn't need a newer glibc than Hyprland has, or Hyprland loses OpenGL.
  - Driver: `objdump -T $(nix eval --raw .#nixosConfigurations.boreas.config.hardware.graphics.package)/lib/libgallium-*.so | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1`
  - Hyprland: `nix-store -qR $(nix eval --raw .#nixosConfigurations.boreas.config.programs.hyprland.package) | grep -o 'glibc-2\.[0-9]*' | sort -uV`

## Upstream: sysc-greet

Contributions to [Nomadcxx/sysc-greet](https://github.com/Nomadcxx/sysc-greet) that would let `modules/nixos/greet.nix` drop its workarounds.

- [ ] Fix focus contrast in code, for every theme
  - Field labels use `Primary` when focused and `FgSecondary` when not (`getFocusColor` in `cmd/sysc-greet/theme.go`). Many palettes make these nearly as bright as each other, or make the unfocused one brighter. Void is ~1.3:1, Catppuccin ~1.15:1, Tokyo Night ~1.2:1.
  - Return `FgMuted` for unfocused labels.
  - Set `Styles.Blurred.Text` on the username/password inputs (`applyInputTheme` in `cmd/sysc-greet/main.go`). Only `Styles.Focused` is set today.
  - Add a non-colour cue on the focused field, e.g. a `▸` marker before its label.
  - Once merged, the `fg_secondary` overrides in `greet.nix` (`greeterThemes`) can go.
- [ ] Add a `themes` option to the NixOS module (`nixosModules.default` in `flake.nix`)
  - Custom themes are documented as going in `/usr/share/sysc-greet/themes/` or `~/.config/sysc-greet/themes/`. On NixOS the first is a read-only store symlink, so the only working location is the greeter's `/var/lib/greeter/.config/sysc-greet/themes/`, and the module has no option for it.
  - A GitHub search (2026-10-26) found no Nix config shipping custom themes, and no upstream issue or PR asking for this. Closest: #46 "Config save for immutable systems" (closed, nothing implemented).
  - Proposed shape: `themes = attrsOf (TOML attrs)`, rendered with `pkgs.formats.toml` into the package's `share/sysc-greet/themes` or linked into the greeter's config dir. Validate the 11 required colour fields at eval time; sysc-greet silently skips incomplete themes.
  - Once merged, replace the tmpfiles links in `greet.nix` with the option.
