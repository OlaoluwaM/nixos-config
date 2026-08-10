# Caffyne Migration — Code Review

- **Date:** 2026-08-09
- **Target:** `main...caffyne-migration`, plus the uncommitted working-tree edits to `modules/home-manager/hyprland/caffyne.nix` (assertion tightening, alignment enum, jq merge fix, documentation comments). The four `caffyne-*.patch` files were reviewed against the pinned caffyne-shell source (`caffyne-org/caffyne-shell` @ `8b2a8ee`).
- **Effort:** high (workflow-backed: one finder per correctness angle plus a cleanup finder, then an independent adversarial verifier per candidate finding; 16 raw findings verified down to 10).

**Resolution (2026-08-09):** all findings addressed in the working tree except #1 (left per decision — commit the re-added `flake.lock` when ready) and #3 (investigated: the reorder is deliberate and required for fpath/compinit; now documented in a maintainer comment). See the per-finding status markers.

**How to read this list:** findings are ranked most-severe first. `CONFIRMED` means an independent verifier reproduced the reasoning against the actual code; `PLAUSIBLE` means it survived verification but hinges on conditions not provable from the code alone (timing, hardware). `correctness` findings misbehave at runtime; `cleanup` findings are drift/duplication/efficiency issues that don't break anything today.

---

## Correctness

### 1. `flake.lock` deleted — caffyne input unpinned on the branch — CONFIRMED — **SKIPPED (left per decision)**

**File:** `flake.lock:1` (deleted in commit `38ab087`)

Branch commit `38ab087` deletes `flake.lock` entirely, so the branch as committed has no pin for the caffyne-shell input that the four patches, the postPatch schema check, and `caffyne.nix`'s widget/variant/group tables were all authored against. The re-added lock exists only as an uncommitted working-tree change.

**Failure scenario:** anyone building the branch as committed (fresh clone, CI, boreas VM dry-run) locks caffyne-shell at current upstream HEAD. Once upstream moves, the build fails on a patch hunk or the `UserOptions.save()` schema check — or worse, the patches still apply against a drifted tree and the eval-time assertions validate bar layouts against rules that no longer match the running shell, producing bars with silently missing widgets.

**Fix:** commit the working-tree `flake.lock`.

### 2. Night-mode setter guards on stale cached `_enabled` state — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/caffyne-hypridle-hyprlock.patch:277` (and the `services/night_mode.py` hunk around patch line 59)

The night-mode tile's map refresh updates only the visual from `systemctl is-active`, while `NightModeService`'s setter guard `if value == self._enabled: return` compares against a snapshot taken once at service construction that nothing ever re-reads from the unit. The toggle silently no-ops whenever the unit's real state diverges from the cache.

**Failure scenario:** caffyne-shell and `hyprsunset.service` start concurrently under the session target; the service caches `_enabled=False` while the unit activates moments later. The tile shows night mode on, but clicking it off hits the guard (`False == False`) and never runs `systemctl --user stop hyprsunset.service` — the display stays orange while the tile visually flips off. The mirror case makes it impossible to turn night mode on from the tile. (`CaffieneButton` avoids this by always shelling out; `NightModeButton` routes through the stale-guarded setter.)

### 3. Dotfile zsh hook now sourced before oh-my-zsh — CONFIRMED — **NO CHANGE NEEDED (intentional; now documented)**

**File:** `modules/home-manager/zsh.nix:119`

The dotfile-sourcing hook moved from `lib.mkAfter` (sourced last, after oh-my-zsh and all Home Manager zsh init) to `lib.mkOrder 790` (before oh-my-zsh loads), removing the "user dotfile wins" invariant with nothing later re-applying the dotfile's settings.

**Failure scenario:** any alias, keybinding, or zstyle in `~/.zshrc.nix.zsh` that collides with an oh-my-zsh plugin definition is silently clobbered when OMZ loads afterwards (a custom `gco` reverts to the git plugin's version), and dotfile lines that depend on OMZ having loaded (an `unalias` of a plugin alias, plugin functions) error on every new interactive shell.

### 4. Wi-Fi connect poll can report a stale failure on success — PLAUSIBLE — **FIXED**

**File:** `modules/home-manager/hyprland/caffyne-runtime-integration.patch:73`

`WifiConnectRequest._poll_child` completes with whatever terminal tuple was last stored when the nmcli child exits, instead of preferring the `ACTIVATED` signal that races the exit, so an intermediate `DISCONNECTED`/`NEED_AUTH` transition can be reported as the final result of a successful connection.

**Failure scenario:** switching from network A to password-protected network B: NetworkManager first drops the device to `DISCONNECTED` (recorded as a terminal failure), then activates B as nmcli exits 0. If the 100 ms poll observes the exit before GLib dispatches `ACTIVATED`, the UI shows "Failed (new-activation)" despite being connected. In the sibling ordering the poll source is dropped and a successful connection resolves only via the 30 s timeout as "Connection timed out".

### 5. Backlight loop breaks on the first device even when degenerate — PLAUSIBLE — **FIXED**

**File:** `modules/home-manager/hyprland/scripts/hypr-shell-status.sh:190`

The backlight loop breaks unconditionally after the first `/sys/class/backlight` entry with a brightness file, so a first device with an empty or zero `max_brightness` leaves all brightness fields null and the real panel backlight is never tried.

**Failure scenario:** on a machine exposing two backlight entries where the glob-first one is degenerate (ddcci/vendor device with `max_brightness` 0) and the second is the real panel, the guard fails but the unconditional `break` exits the loop; `bright_pct`/`raw`/`max` emit null every poll and the Quickshell brightness readout and OSD treat the machine as having no backlight.

## Cleanup

### 6. `hypr-shell-awww` lacks the `After=` ordering fix `caffyne-awww` got — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/default.nix:815`

`hypr-shell-awww` duplicates `caffyne-awww` but has drifted: `caffyne-awww` was given `After = [ hyprlandSessionTarget ]` with a comment explaining why, while the Quickshell twin never got the same ordering. On the quickshell backend, systemd is free to start awww before the Hyprland session target is up; the daemon fails against no compositor and burns through its restart budget — exactly the failure mode the `caffyne-awww` comment documents.

### 7. Patched `caffiene.py` hand-rolls caffeine unit control — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/caffyne-hypridle-hyprlock.patch:220`

The patch reimplements start/stop/is-active against the hardcoded unit name `hypr-shell-caffeine.service` even though `cfg.commands.caffeineScript` is deliberately placed on Caffyne's service PATH for this purpose. The unit name and toggle semantics now live in three places (the `default.nix` unit, `scripts/hypr-shell-caffeine.sh`, this patch); renaming the unit or changing toggle behavior in the script silently desynchronizes the Caffyne tile.

### 8. Mirrored widget/variant tables have no build-time guard — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/caffyne.nix:49`

`barWidgetVariants`, `invalidGroupPairs`, and `desktopAppletNames` are hand-mirrored from upstream with no build-time check, unlike the sections schema which `caffyneSchemaCheck` AST-verifies in postPatch; the module's own comment admits the gap. On a pin update that renames a widget, changes a `VARIANTS` list, or adds an incompatible pair, the build succeeds and eval-time assertions validate layouts against stale rules — a declared bar can reference a widget or variant the running shell no longer accepts, reproducing the silent-drop failure mode the assertions exist to prevent.

### 9. `_unit_is_active` helper copy-pasted three times in the patch — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/caffyne-hypridle-hyprlock.patch:247`

`services/night_mode.py`, `buttons/caffiene.py`, and `buttons/night_mode.py` each define an identical `subprocess.run(['systemctl','--user','is-active',...])` helper differing only in unit name. Every pin update regenerates this patch, and any fix to the check (timeout, error handling) must be applied in three places; missing one leaves the tiles disagreeing about unit state.

### 10. Seven nmcli forks per poll where one call suffices — CONFIRMED — **FIXED**

**File:** `modules/home-manager/hyprland/scripts/hypr-shell-status.sh:236`

For the default-route device the script forks nmcli seven times (`GENERAL.TYPE`, `GENERAL.CONNECTION`, `GENERAL.STATE`, `GENERAL.METERED`, `IP4.ADDRESS`, `IP4.GATEWAY`, `IP6.ADDRESS`) on the QML bar's ~2 s poll loop, plus one more per active VPN connection, where a single multi-field `nmcli -g` call returns everything. Each fork is a process spawn plus a D-Bus round trip to NetworkManager — hundreds per minute, a measurable battery and CPU cost for data one invocation provides.

---

## Related: module-level review of `caffyne.nix` (same session, already applied)

A separate deep review of `modules/home-manager/hyprland/caffyne.nix` against the pinned source found and fixed three issues (uncommitted in the working tree):

1. **`desktop_canvas.placements` ownership leak** — jq's `*` recursively merges the monitor-keyed object, so runtime placements on undeclared monitors survived activation; the reconcile filter now force-assigns the section.
2. **Groups must contain exactly two widgets** — the pinned bar silently drops any other size; the shape assertion now requires length 2.
3. **`alignment` restricted to top/bottom** — the pinned Bar is horizontal-only; left/right serialized but produced a broken surface.

Three soft invariants were documented as maintainer comments rather than enforced: `roundedEdges`/`floatingApplets` are serialized-but-unread in this pin, group members aren't restricted to applet-capable widgets, and duplicate widgets per monitor aren't asserted.
