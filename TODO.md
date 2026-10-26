# TODO

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
