{
  config,
  lib,
  pkgs,
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
  # Local copies used only by the `on = hyprland.shutdown` handler below.
  # keybindings.nix keeps its own copies for its binds; small duplication
  # between sibling modules is fine, cross-module coupling is not.
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
in
{
  config = lib.mkIf cfg.enable {
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

      # When Hyprland starts, Home Manager can copy important session variables
      # into the environment inherited by services run through `systemctl --user`
      # before starting hyprland-session.target. Services started this way, such
      # as hypridle, hyprsunset, and Vicinae, need these values to know which
      # Wayland/Hyprland session they belong to. Without them, those services
      # can start but fail to talk to the compositor, portals, or the right
      # display.
      systemd = {
        enable = true;
        variables = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_DESKTOP"
          "XDG_SESSION_TYPE"
          # Repo-specific: read by the wallpaper pipeline (wallpaper.nix).
          "WALLPAPERS_DIR"
        ];
      };

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
        # Keeps occupied workspaces contiguous from 1: when a middle
        # workspace empties, everything above shifts down -- so like GNOME,
        # closing the last window on a workspace collapses it and the
        # workspace you are looking at inherits the next one's windows.
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
        # fires several events), and re-entrancy self-terminates: our own
        # moves re-schedule one more pass, which finds the layout already
        # compact and does nothing.
        wsCompact = {
          _var = lua ''
            (function()
              local pending = false
              local function compact()
                pending = false
                local monitors = {}
                local normal = {}
                for _, ws in ipairs(hl.get_workspaces()) do
                  if ws.id > 0 and not ws.special then
                    table.insert(normal, ws)
                    monitors[ws.monitor and ws.monitor.name or "?"] = true
                  end
                end
                local monitorCount = 0
                for _ in pairs(monitors) do monitorCount = monitorCount + 1 end
                if monitorCount > 1 then return end
                table.sort(normal, function(a, b) return a.id < b.id end)
                local expected = 1
                local activeId = 0
                for _, ws in ipairs(normal) do
                  if ws.active then activeId = ws.id end
                  if ws.windows > 0 then
                    if ws.id ~= expected then
                      for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
                        hl.dispatch(hl.dsp.window.move({
                          workspace = expected,
                          window = "address:" .. tostring(w.address),
                          silent = true,
                        }))
                      end
                    end
                    expected = expected + 1
                  end
                end
                -- stranded past the trailing empty (expected is exactly the
                -- GNOME "one empty at the end" slot): walk back to it
                if activeId > expected then
                  hl.dispatch(hl.dsp.focus({ workspace = expected }))
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

        on = [
          # Runs when Hyprland is already shutting down so no need for
          # hyprshutdown.
          {
            _args = [
              "hyprland.shutdown"
              (lua ''
                function()
                  hl.exec_cmd(${luaString "${pkgs.systemd}/bin/systemctl --user stop ${config.wayland.systemd.target}"})
                end
              '')
            ];
          }
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

          decoration = {
            rounding = 14;
            rounding_power = 3.5;
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
              vibrancy = 0.4;
            };
            shadow = {
              enabled = true;
              range = 12;
              render_power = 2;
              color = "rgba(${stripHash theme.shadowColor})";
            };
          };

          animations = {
            enabled = true;
          };

          dwindle = {
            preserve_split = true;
          };

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            focus_on_activate = true;
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
