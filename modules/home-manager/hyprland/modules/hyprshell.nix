{
  config,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# hyprshell is a GTK4 daemon that reproduces GNOME's Alt-Tab: a visual
# window switcher with app icons and most-recently-used ordering. It also
# ships an application launcher/overview mode, which this profile leaves
# off -- Vicinae (../vicinae.nix) is the sole launcher here.
#
# hyprshell registers its own Hyprland keybinds at runtime (via the
# hyprland-rs dynamic bind API, not `bind=` lines) as soon as the daemon
# starts, driven entirely by `windows.switch` in the config below. Confirmed
# by reading hyprshell 4.10.4's source (crates/windows-lib/src/keybinds.rs,
# crates/exec-lib/src/binds.rs): on startup it calls hyprctl's bind keyword
# once per action -- open forward (Alt+Tab), open reverse (Alt+`  and
# Alt+Shift+Tab), and release-to-close (Alt release) -- so Shift+Alt+Tab
# reverse cycling comes for free without a second config block or a second
# keybind. This is why Alt+Tab is NOT declared in keybindings.nix, unlike
# every other chord in this profile: there is nothing for Hyprland's own
# config to bind, the daemon owns the grab.
let
  cfg = config.local.hyprland;
  hyprlandSessionTarget = config.wayland.systemd.target;

  # Minimal config: enabling `windows.switch` is enough to get the
  # GNOME-like switcher -- icons and MRU order are both built into Switch
  # mode itself, not options. `filter_by: []` means no workspace/monitor/
  # class filtering, so every window on every workspace shows up (upstream's
  # own default is `[current_monitor]`, which this profile deliberately
  # overrides for the "all workspaces" scope GNOME's switcher has).
  #
  # `windows.overview` (the launcher/app-search surface) and `windows.
  # switch_2` (a second, independently-configurable switcher) are both left
  # unset. CONFIGURE.md is explicit that omitting a `windows.*` section is
  # how you disable that mode -- Vicinae keeps sole ownership of launching.
  #
  # `version` pins the on-disk schema hyprshell 4.10.4 expects
  # (config-lib::CURRENT_CONFIG_VERSION). Omitting it doesn't break
  # anything -- serde still fills in every field's default -- but every
  # `hyprshell config check`/`explain` run then prints a spurious "Config
  # file does not have a version specified" migration warning, since the
  # migration check special-cases a missing version instead of treating it
  # like any other defaulted field.
  hyprshellConfig = builtins.toJSON {
    version = 4;
    windows.switch = {
      modifier = "alt";
      filter_by = [ ];
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.hyprshell ];

    # Written as config.json rather than the CLI's default config.ron:
    # hyprshell's own default-path probe (crates/core-lib/src/path.rs)
    # checks, in order, config.ron, config.toml, config.json, then
    # config.json5, and uses whichever exists -- so a bare `hyprshell run`
    # with no `-c` picks this file up. This is the same shape upstream's own
    # home-manager module (nix/module.nix) writes.
    xdg.configFile."hyprshell/config.json".text = hyprshellConfig;

    systemd.user.services.hyprshell = {
      Unit = {
        Description = "hyprshell Alt-Tab window switcher";
        # Same ordering rationale as silere-shell's unit: without this,
        # systemd may race the daemon's Hyprland IPC connection (needed to
        # register the Alt-Tab bind) ahead of Hyprland itself being up.
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = "${lib.getExe pkgs.hyprshell} run";
        Restart = "on-failure";
      };
    };
  };
}
