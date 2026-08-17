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
  #
  # `windows.scale` grows the switcher's icons (and, downstream of them,
  # the tiles). Read straight from crates/windows-lib/src/switch/
  # clients.rs (v4.10.4, as patched by `./hyprshell-switcher-tiles.patch`
  # below): `calc_image_size` divides the monitor's resolution by
  # `15 - scale`, so a higher value shrinks that denominator and grows the
  # icon -- there is no separate "icon size" knob. config-lib's
  # `#[default = 8.5]` on `Windows::scale` (crates/config-lib/src/io/
  # config.rs) already yields a 133px icon on this machine's 2560x1600
  # monitor (`(1600 / 6.5).clamp(50, 600) / 1.6 - 20`); 9.5 pushes that to
  # 161px (`1600 / 5.5 -> 290 -> 290/1.6-20`), noticeably bigger. Upstream
  # additionally sized each tile's Button from raw monitor width/height
  # (`scale(monitor.width/height, scale)`, ~465x290px here) regardless of
  # icon size; the patch below deletes that pair of requests, so tile size
  # is no longer coupled to `windows.scale` at all -- it now falls out of
  # icon size, label width, and CSS padding, per the patch comment.
  hyprshellConfig = builtins.toJSON {
    version = 4;
    windows = {
      scale = 9.5;
      switch = {
        modifier = "alt";
        filter_by = [ ];
      };
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
  # `.client-image` is the icon; `.client-label` is the title. Upstream
  # renders that title as a GtkFrame label-widget, which GTK4 always pins
  # to the frame's TOP edge -- no CSS property moves it, since it isn't a
  # normal child, it's the frame's border-drawing label. That put the app
  # name above the icon instead of below it like GNOME's real switcher, so
  # `hyprshellPackage` below patches clients.rs to swap the Frame for a
  # plain vertical Box (icon, then label) before this stylesheet ever
  # runs; `.client-label` is a class this repo's patch adds for that reason.
  #
  # src/root.rs's `apply_css` loads default_styles.css, then windows-lib's
  # built-in styles.css, then this file last -- all at
  # STYLE_PROVIDER_PRIORITY_USER, and GTK breaks same-priority ties by
  # insertion order, so equal-specificity rules here win over the built-ins
  # without needing `!important`.
  #
  # Icon pixel size is out of CSS's reach -- clients.rs computes it in Rust
  # from window/monitor geometry via `set_pixel_size` (see `windows.scale`
  # above), which CSS's `-gtk-icon-size` (icon-name icons only) can't
  # override. Tile size used to be out of CSS's reach too, pinned to a
  # monitor-derived Button request regardless of content; now that
  # `hyprshell-switcher-tiles.patch` deletes that request and the Button
  # sizes to its icon+label Box (see the patch comment below), `.client`'s
  # padding is the only thing standing between "hugs the icon" and "still
  # looks bloated" -- trimmed from 4px 6px to 3px 5px (radius 12px to
  # 10px to match) now that the tile is genuinely content-sized. `.monitor`
  # padding is left at 6px: it wraps the whole FlowBox, not a single tile,
  # and 6px already read as tight against a photo of GNOME's real
  # switcher.
  hyprshellStyles = ''
    .window {
      color: #eeeeee;
    }

    .monitor {
      background: rgba(30, 30, 30, 0.95);
      border: none;
      border-radius: 18px;
      box-shadow: 0 8px 8px rgba(0, 0, 0, 0.3);
      padding: 6px;
    }

    .client {
      background: transparent;
      border: none;
      border-radius: 10px;
      margin: 3px;
      padding: 3px 5px;
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

    .client-label {
      color: #eeeeee;
      font-weight: 500;
      font-size: 0.85em;
      text-decoration: none;
    }
  '';

  # `./hyprshell-switcher-tiles.patch` reshapes the switcher tile's
  # `view!` block in crates/windows-lib/src/switch/clients.rs, for two
  # things neither config nor CSS can reach:
  #
  # 1. Label placement: upstream renders the app name as a GtkFrame
  #    label-widget, which GTK4 always pins to the frame's TOP edge -- no
  #    CSS property moves it, since it isn't a normal child, it's the
  #    frame's border-drawing label. The patch swaps that Frame for a
  #    plain vertical Box (icon, then label) so the name sits below the
  #    icon like GNOME's real switcher (see the styles comment above).
  # 2. Tile size: upstream also gives the tile's Button a fixed
  #    `set_width_request`/`set_height_request` derived from raw monitor
  #    width/height (`scale(monitor.width/height, windows.scale)`, ~465x
  #    290px on this machine) -- enormous compared to the icon, and the
  #    reason the switcher read as oversized even after the icon/label
  #    fix above. The patch deletes both requests so the Button sizes to
  #    its Box's content instead, and gives the Label a `set_width_request`
  #    of `calc_image_size(...)` (the same expression that sizes the icon)
  #    so one long window title can't stretch its tile past the icon's
  #    width -- it ellipsizes instead, same as GNOME's own switcher.
  #
  # Keep it minimal: it touches one `view!` block and nothing else, so
  # it's cheap to rebase across hyprshell version bumps, but it WILL need
  # rebasing whenever upstream reshapes that block (already true once for
  # the 4.11-alpha line, which reworks the CSS surface this module also
  # depends on -- see the styles comment above).
  hyprshellPackage = pkgs.hyprshell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./hyprshell-switcher-tiles.patch ];
  });
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ hyprshellPackage ];

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
        ExecStart = "${lib.getExe hyprshellPackage} run";
        Restart = "on-failure";
      };
    };
  };
}
