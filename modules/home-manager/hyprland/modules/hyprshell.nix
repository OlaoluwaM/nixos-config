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

  # GNOME Shell app-switcher look, reproduced (not reinvented) from GNOME's
  # own theme: gnome-shell-sass/widgets/_switcher-popup.scss supplies the
  # selected-item highlight (white at 20% alpha, ~12-16px radius) and
  # _osd.scss supplies the modal popup panel (near-opaque dark charcoal,
  # ~28px corner radius, soft drop shadow).
  #
  # Selector vocabulary is hyprshell 4.10.4's, not guessed: read straight
  # from crates/windows-lib/src/switch/{root,clients}.rs and the built-in
  # crates/windows-lib/src/styles.css at the v4.10.4 tag (the 4.11-alpha
  # line reworks the CSS surface, so main/HEAD isn't a safe reference).
  # `.window` is the switcher's top-level ApplicationWindow; `.monitor` is
  # the FlowBox panel both switch sub-modes share (root.rs sets it on
  # whichever FlowBox is active); `.client`/`.client.active` are each
  # window's Button (`filter_by: []` above leaves `switch_workspaces` at
  # its config-lib default of `false`, so this profile always renders the
  # flat clients_only FlowBox -- `.workspace` never appears here);
  # `.client-image` is the icon; the unclassed `label` inside each Frame is
  # the title GtkFrame draws as a label-widget (clients.rs's
  # `set_label_widget`).
  #
  # src/root.rs's `apply_css` loads default_styles.css, then windows-lib's
  # built-in styles.css, then this file last -- all at
  # STYLE_PROVIDER_PRIORITY_USER, and GTK breaks same-priority ties by
  # insertion order, so equal-specificity rules here win over the built-ins
  # without needing `!important`.
  #
  # GtkFrame always draws its label-widget at the frame's top edge, so
  # unlike GNOME's real switcher (one caption below the whole strip) each
  # tile gets its own title slot; hiding it except on `.active` reproduces
  # GNOME's "only the current selection is captioned" behavior within that
  # constraint. Icon pixel size is out of CSS's reach -- clients.rs computes
  # it in Rust from window/monitor geometry via `set_pixel_size`, which
  # CSS's `-gtk-icon-size` (icon-name icons only) can't override.
  hyprshellStyles = ''
    .window {
      color: #eeeeee;
    }

    .monitor {
      background: rgba(30, 30, 30, 0.95);
      border: none;
      border-radius: 28px;
      box-shadow: 0 8px 8px rgba(0, 0, 0, 0.3);
      padding: 12px;
    }

    .client {
      background: transparent;
      border: none;
      border-radius: 16px;
      margin: 12px;
      padding: 12px;
      min-width: 128px;
      min-height: 128px;
      transition: background 150ms ease;
    }

    .client:hover {
      background: rgba(255, 255, 255, 0.12);
    }

    .client.active {
      background: rgba(255, 255, 255, 0.2);
    }

    .client.active:hover {
      background: rgba(255, 255, 255, 0.28);
    }

    .client label {
      opacity: 0;
      color: #eeeeee;
      font-weight: 500;
      text-decoration: none;
    }

    .client.active label {
      opacity: 1;
    }
  '';
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

    # Same default-path probe as config.json above (crates/core-lib/src/
    # path.rs's `get_default_css_file`): a bare `hyprshell run` with no `-s`
    # reads $XDG_CONFIG_HOME/hyprshell/styles.css, so no ExecStart change is
    # needed to pick this up.
    xdg.configFile."hyprshell/styles.css".text = hyprshellStyles;

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
