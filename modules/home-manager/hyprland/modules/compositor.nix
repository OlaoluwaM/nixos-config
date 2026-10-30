{
  config,
  lib,
  pkgs,
  inputs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This module owns the compositor config itself: monitors, env vars, input,
# general/decoration/animation settings, curves, and window rules -- the
# `wayland.windowManager.hyprland` block. It does NOT own key chords:
# keybindings.nix merges its own `settings.bind` list into this same option
# tree from outside, so the two modules combine into one hyprland.lua without
# either needing to import the other.
let
  cfg = config.local.hyprland;
  theme = config.local.theme.colors;
  stripHash = s: lib.removePrefix "#" s;
  # Local copy used by wsCompact and the event handlers below.
  # keybindings.nix keeps its own copy for its binds; small duplication
  # between sibling modules is fine, cross-module coupling is not.
  lua = lib.generators.mkLuaInline;
in
{
  config = lib.mkIf cfg.enable {
    # The same package modules/nixos/hyprland.nix installs (both read
    # ../source.nix), shared with the helper scripts through the commands
    # tree (see commands.nix).
    local.hyprland.commands.hyprlandPackage =
      (import ../source.nix { inherit inputs unstable pkgs; }).hyprland;

    wayland.windowManager.hyprland = {
      enable = true;

      # The NixOS module already installs Hyprland and its portal package. Home
      # Manager's wayland.windowManager.hyprland.package docs say to set this
      # to null when the NixOS module installs Hyprland:
      # https://nix-community.github.io/home-manager/options.xhtml#opt-wayland.windowManager.hyprland.package
      #
      # Home Manager owns the user config and hyprland-session.target here. The
      # NixOS Hyprland module owns both portal packages, so disable Home
      # Manager's duplicate portal contribution as well.
      package = null;
      portalPackage = null;

      # Hyprland 0.55+ and Home Manager 26.05 support Lua config generation.
      # Keep this explicit so the profile writes ~/.config/hypr/hyprland.lua
      # regardless of future Home Manager default changes.
      configType = "lua";

      # Hyprland (0.57+) runs the session target itself: at startup it imports
      # DISPLAY, WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE,
      # XDG_CURRENT_DESKTOP, PATH and XDG_DATA_DIRS into the systemd user
      # manager and starts hyprland-session.target, and on exit it stops
      # graphical-session.target. Home Manager's integration did the same job
      # from a hyprland.start hook, which now fires after Hyprland's own start
      # and stop/start-cycled the target, so every session service started
      # twice per login. Off here; default.nix links upstream's target unit
      # and puts the variables Hyprland doesn't import (XDG_SESSION_TYPE,
      # XDG_SESSION_DESKTOP, WALLPAPERS_DIR) in environment.d, where the user
      # manager has them before anything starts.
      systemd.enable = false;

      settings = {
        # Enable switching workspaces with a three finger swipe
        gesture = {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        };

        # GNOME lets a swipe continue past the last workspace into a fresh
        # empty one; with the wsCompact collapser below, that swipe-created
        # workspace IS the dynamic model's trailing empty slot.
        config.gestures.workspace_swipe_create_new = true;

        # Monitor rule. Blank monitor name means "apply to all monitors".
        # preferred = use the monitor's preferred resolution/refresh rate.
        # auto = let Hyprland choose the position. 1 = scale factor.
        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        };

        env = [
          {
            _args = [
              "XDG_CURRENT_DESKTOP"
              "Hyprland"
            ];
          }
          {
            _args = [
              "XDG_SESSION_DESKTOP"
              "Hyprland"
            ];
          }
          {
            _args = [
              "NIXOS_OZONE_WL"
              "1"
            ];
          }
        ];

        # GNOME-style dynamic workspaces, compositor half (the bar's widget
        # half reads the same state through the shell's wsDynamic mode).
        # Keeps occupied workspaces contiguous from 1 by renumbering them
        # (hl.dsp.workspace.change_id, 0.56+) rather than moving windows, so
        # a shifted workspace keeps its tiling layout and its identity --
        # which is what a workspace screen-share follows, so a stream of it
        # survives the shift. The bar hears each renumber as the
        # changeworkspaceid event, which the fork's CompositorHyprland
        # already refreshes on.
        #
        # Like GNOME, the empty workspace you are looking at stays put: if
        # you close the last window on a middle workspace, nothing slides in.
        # Its number is still taken, so the pass stops there; once you leave,
        # Hyprland drops the empty workspace, workspace.removed fires, and
        # the next pass shifts everything above it down. An empty workspace
        # you land on past the trailing slot (Super+5 with two occupied) is
        # renumbered into that slot, GNOME's "one empty at the end".
        #
        # Runs in-process via hl.dispatch (verified live: dispatcher objects
        # are invocable through hl.dispatch even though binds are their usual
        # home), so no hyprctl child processes and no external daemon.
        #
        # Deliberately inert with more than one monitor showing normal
        # workspaces: Hyprland gives every monitor its own global workspace
        # ids, so a global 1..N compaction would drag windows across
        # monitors. Single-monitor is this laptop's daily reality; revisit
        # the per-monitor id allocation if a dock becomes permanent.
        #
        # The 200ms one-shot timer coalesces event bursts (closing a window
        # fires several events). Renumbering fires none of the events below,
        # so a pass never re-triggers itself.
        #
        # Since 0.57 special workspaces have no number, so their ws.id is
        # nil rather than negative; the nil check keeps `ws.id > 0` from
        # raising and aborting the whole pass while a scratchpad exists.
        # change_id refuses a number any workspace holds, hence the `taken`
        # table: Hyprland only keeps an empty workspace while it is the one
        # being viewed, or if a workspace rule makes it persistent (none
        # here), so a taken target means "the viewed empty one".
        wsCompact = {
          _var = lua ''
            (function()
              local pending = false
              local function compact()
                pending = false
                local monitors = {}
                local normal = {}
                for _, ws in ipairs(hl.get_workspaces()) do
                  if ws.id and ws.id > 0 and not ws.special then
                    table.insert(normal, ws)
                    monitors[ws.monitor and ws.monitor.name or "?"] = true
                  end
                end
                local monitorCount = 0
                for _ in pairs(monitors) do monitorCount = monitorCount + 1 end
                if monitorCount > 1 then return end
                table.sort(normal, function(a, b) return a.id < b.id end)
                local taken = {}
                local viewedEmpty = nil
                for _, ws in ipairs(normal) do
                  taken[ws.id] = true
                  if ws.active and ws.windows == 0 then viewedEmpty = ws.id end
                end
                local function renumber(from, to)
                  hl.dispatch(hl.dsp.workspace.change_id({ workspace = from, id = to }))
                  taken[from] = nil
                  taken[to] = true
                end
                local expected = 1
                for _, ws in ipairs(normal) do
                  if ws.windows > 0 then
                    if ws.id ~= expected then
                      -- the viewed empty workspace holds this number: leave
                      -- everything above it alone until it is left
                      if taken[expected] then return end
                      renumber(ws.id, expected)
                    end
                    expected = expected + 1
                  end
                end
                -- the viewed empty workspace past the trailing slot
                -- (expected is exactly GNOME's "one empty at the end")
                if viewedEmpty and viewedEmpty > expected and not taken[expected] then
                  renumber(viewedEmpty, expected)
                end
              end
              return function()
                if pending then return end
                pending = true
                hl.timer(compact, { timeout = 200, type = "oneshot" })
              end
            end)()
          '';
        };

        # No hyprland.shutdown handler stopping the session target: since
        # 0.57, a Hyprland that started hyprland-session.target itself stops
        # graphical-session.target on exit, and upstream's target is BindsTo=
        # that, so the session services stop with it. Hyprland skips both
        # halves under HYPRLAND_NO_SD_TARGET or when launched by systemd
        # (MANAGERPID set); neither applies to the greetd launch here, but
        # either would need the handler and Home Manager's integration back.
        on = [
          # The three ways a workspace can lose its last window. window.destroy
          # rather than window.close: close is the request, destroy the unmap.
          {
            _args = [
              "window.destroy"
              (lua "function() wsCompact() end")
            ];
          }
          {
            _args = [
              "window.move_to_workspace"
              (lua "function() wsCompact() end")
            ];
          }
          {
            _args = [
              "workspace.removed"
              (lua "function() wsCompact() end")
            ];
          }
        ];

        config = {
          input = {
            kb_layout = "us";
            follow_mouse = 1;
            touchpad = {
              natural_scroll = true;
              # GNOME's clickfinger model instead of corner areas: a
              # two-finger tap/click is right-click, three fingers middle.
              clickfinger_behavior = true;
            };
          };

          general = {
            gaps_in = 4;
            gaps_out = 8;
            border_size = 2;
            "col.active_border" = "rgb(${stripHash theme.primary})";
            "col.inactive_border" = "rgb(${stripHash theme.outline})";
            layout = "dwindle";
          };

          xwayland = {
            force_zero_scaling = true; # Have XWayland apps scale correctly under Wayland
          };

          decoration = {
            rounding = 14;
            rounding_power = 3.5;
            dim_inactive = true;
            dim_strength = 0.3;
            blur = {
              enabled = true;
              # Frosted-glass tuning for the shell's layer surfaces (the only
              # translucent surfaces in this profile -- windows are opaque, so
              # these globals cost nothing elsewhere). 8/3 gives a wide, soft
              # frost instead of the tight smear 5/2 produced; vibrancy pulls
              # the wallpaper's saturation up through the blur, which is what
              # makes the glass read as tinted by the wallpaper rather than
              # gray.
              size = 8;
              passes = 3;
              # Lifted with the shell's adaptive glass (fork ADR 0004): the
              # shell thins and lifts its panes over dark wallpapers, and
              # these give the blur behind them something to show. Static
              # and global on purpose -- a per-wallpaper hyprctl push would be
              # lost on reload and would adapt on a different clock from the
              # shell -- so the values sit where the mid-dark band of the
              # collection reads as frost without washing out bright ones.
              vibrancy = 0.6;
              vibrancy_darkness = 0.3;
              brightness = 1.1;
              # 0.57 blur variants layer a finish over the kawase blur above.
              # "frost" is the static frosted-glass finish (no per-frame cost,
              # unlike the animated ones such as water or aurora), tuned by
              # the decoration:blur:glass:* defaults. A look to judge live;
              # "kawase" is plain blur again.
              variant = "frost";
              # Fades the blur with each pixel's own opacity instead of
              # cutting it off, so the shell's anti-aliased rounded corners
              # and soft pane edges don't end on a hard frosted rim.
              # ignore_alpha in the layer rules below still drops the
              # near-transparent margins entirely. Needs
              # render:use_shader_blur_blend (set below); upstream marks
              # that blend path experimental.
              proportional = true;
            };
            # Window shadows off (2026-08-23): the flat look won. The old
            # tuning (range 12, render_power 2, theme.shadowColor) is gone
            # with the toggle rather than left as dead keys; theme.shadowColor
            # itself stays defined in theme.nix for any surface that wants it.
            shadow.enabled = false;
          };

          animations = {
            enabled = true;
          };

          dwindle = {
            preserve_split = true;
          };

          # decoration:blur:proportional only works on this blend path.
          render.use_shader_blur_blend = true;

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            focus_on_activate = true;
            # Hyprland keeps the session locked when a lock client dies, but
            # without this it refuses every new client, and the dead lock is
            # unrecoverable. The silere-lock wrapper (commands.nix) relies on
            # it to hand a failed lock to hyprlock.
            allow_session_lock_restore = true;
          };
        };

        curve = {
          _args = [
            "easeOut"
            {
              type = "bezier";
              points = [
                [
                  0.22
                  1
                ]
                [
                  0.36
                  1
                ]
              ];
            }
          ];
        };

        animation = [
          {
            leaf = "windows";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
          {
            leaf = "border";
            enabled = true;
            speed = 4;
            bezier = "default";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 3;
            bezier = "easeOut";
          }
        ];

        # Blur behind every silere layer surface (bar, menu, calendar,
        # quickactions, osd, notifications, traymenu). The shell paints these
        # translucently (bar via barOpacity, popups via the fork's
        # glassSurfaces mode), but without a layerrule Hyprland's blur only
        # applies to windows, so translucency alone just dims the surface
        # instead of frosting it. One prefix regex instead of a rule per
        # namespace so future shell surfaces inherit the glass automatically.
        # Hyprland FULL-matches rule regexes (regex_match, not search), so the
        # pattern must consume the whole namespace -- a bare "^silere-" prefix
        # silently matches nothing.
        # ignore_alpha keeps the blur from haloing the fully transparent
        # regions around rounded corners and floating margins -- pixels at or
        # below the threshold are left unblurred.
        layer_rule = [
          {
            match.namespace = "^silere-.*$";
            blur = true;
            ignore_alpha = 0.2;
          }
          {
            # Vicinae is a layer-shell surface, so regular window blur does
            # not cover it. Match the shell's blur threshold so its Matugen-
            # tinted translucent background reads as the same frosted glass.
            match.namespace = "^(vicinae)$";
            blur = true;
            ignore_alpha = 0.2;
          }
        ];

        window_rule = [
          {
            match.class = "^(vicinae)$";
            float = true;
          }
          {
            match.class = "^(vicinae)$";
            center = true;
          }
          {
            match.class = "^(vicinae)$";
            size = "42% 48%";
          }
          {
            match.class = "^(mission-center)$";
            float = true;
          }
          # No float rule for wifitui's kitty window (wifiEditCommand still
          # launches it with a wifitui-float class for targeting): a centered
          # float covered the whole workspace, and live use preferred it
          # tiling like any other window.
        ];
      };
    };
  };
}
