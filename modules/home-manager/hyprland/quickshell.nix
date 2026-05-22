{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.hyprland;
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/Wallpapers";

  powerProfileScript = pkgs.writeShellApplication {
    name = "hypr-shell-power-profile";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      power-profiles-daemon
    ];
    text = builtins.readFile ./scripts/hypr-shell-power-profile.sh;
  };

  statusScript = pkgs.writeShellApplication {
    name = "hypr-shell-status";
    runtimeInputs = with pkgs; [
      bluez
      brightnessctl
      coreutils
      findutils
      gawk
      gnused
      jq
      lm_sensors
      networkmanager
      pamixer
      playerctl
      powerProfileScript
    ];
    text = builtins.readFile ./scripts/hypr-shell-status.sh;
  };

  popupScript = pkgs.writeShellApplication {
    name = "hypr-shell-popup";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = builtins.readFile ./scripts/hypr-shell-popup.sh;
  };

  timezoneScript = pkgs.writeShellApplication {
    name = "hypr-shell-timezones";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = builtins.readFile ./scripts/hypr-shell-timezones.sh;
  };

  wallpaperScript = pkgs.writeShellApplication {
    name = "hypr-shell-wallpaper";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnused
      swww
    ];
    text = builtins.readFile ./scripts/hypr-shell-wallpaper.sh;
  };

  screenshotScript = pkgs.writeShellApplication {
    name = "hypr-shell-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      hyprland
      jq
      satty
      slurp
      wl-clipboard
    ];
    text = builtins.readFile ./scripts/hypr-shell-screenshot.sh;
  };

  shellQml =
    builtins.replaceStrings
      [
        "@STATUS_SCRIPT@"
        "@TIMEZONE_SCRIPT@"
        "@VICINAE_COMMAND@"
        "@NETWORK_COMMAND@"
        "@BLUETOOTH_COMMAND@"
        "@POWER_COMMAND@"
        "@POWER_PROFILE_COMMAND@"
        "@PAMIXER_COMMAND@"
        "@BRIGHTNESS_COMMAND@"
        "@PLAYERCTL_COMMAND@"
      ]
      [
        "${statusScript}/bin/hypr-shell-status"
        "${timezoneScript}/bin/hypr-shell-timezones"
        "${pkgs.vicinae}/bin/vicinae"
        "${pkgs.networkmanagerapplet}/bin/nm-connection-editor"
        "${pkgs.blueman}/bin/blueman-manager"
        "${unstable.hyprshutdown}/bin/hyprshutdown"
        "${powerProfileScript}/bin/hypr-shell-power-profile"
        "${pkgs.pamixer}/bin/pamixer"
        "${pkgs.brightnessctl}/bin/brightnessctl"
        "${pkgs.playerctl}/bin/playerctl"
      ]
      (builtins.readFile ./quickshell/shell.qml);
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      blueman
      brightnessctl
      # cliphist
      grim
      jq
      libnotify
      lm_sensors
      mission-center
      networkmanagerapplet
      pamixer
      playerctl
      quickshell
      satty
      slurp
      swww
      vicinae
      wl-clipboard
      unstable.hyprshutdown

      powerProfileScript
      popupScript
      statusScript
      timezoneScript
      wallpaperScript
      screenshotScript
    ];

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    xdg.configFile = {
      "quickshell/hyprland/shell.qml".text = shellQml;
      "xdg-terminals.list".text = "kitty.desktop\n";

      "hypr/hyprland.conf".text = ''
        monitor=,preferred,auto,1

        env = XDG_CURRENT_DESKTOP,Hyprland
        env = XDG_SESSION_DESKTOP,Hyprland
        env = NIXOS_OZONE_WL,1

        exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE WALLPAPERS_DIR
        exec-once = systemctl --user start hypr-shell-swww.service
        exec-once = systemctl --user start hypr-shell-wallpaper.service
        exec-once = systemctl --user start hypr-shell-quickshell.service
        exec-once = systemctl --user start hypr-shell-vicinae.service
        # exec-once = systemctl --user start hypr-shell-clipboard.service
        exec-once = systemctl --user start hypridle.service
        exec-once = systemctl --user start hyprpolkitagent.service
        exec-once = systemctl --user start hyprsunset.service
        exec-once = systemctl --user start udiskie.service

        input {
          kb_layout = us
          follow_mouse = 1
          touchpad {
            natural_scroll = true
          }
        }

        general {
          gaps_in = 4
          gaps_out = 8
          border_size = 2
          col.active_border = rgb(b4befe)
          col.inactive_border = rgb(313244)
          layout = dwindle
        }

        decoration {
          rounding = 10
          blur {
            enabled = true
            size = 5
            passes = 2
          }
          shadow {
            enabled = true
            range = 12
            render_power = 2
            color = rgba(11111bdd)
          }
        }

        animations {
          enabled = true
          bezier = easeOut, 0.22, 1, 0.36, 1
          animation = windows, 1, 3, easeOut
          animation = border, 1, 4, default
          animation = fade, 1, 3, easeOut
          animation = workspaces, 1, 3, easeOut
        }

        dwindle {
          pseudotile = true
          preserve_split = true
        }

        misc {
          disable_hyprland_logo = true
          disable_splash_rendering = true
          focus_on_activate = true
        }

        windowrulev2 = float,class:^(vicinae)$
        windowrulev2 = center,class:^(vicinae)$
        windowrulev2 = size 42% 48%,class:^(vicinae)$
        windowrulev2 = float,class:^(nm-connection-editor)$
        windowrulev2 = float,class:^(blueman-manager)$
        windowrulev2 = float,class:^(mission-center)$

        $mod = SUPER
        $terminal = kitty

        bind = $mod, Return, exec, $terminal
        bindr = $mod, SUPER_L, exec, ${pkgs.vicinae}/bin/vicinae open
        bindr = $mod, SUPER_R, exec, ${pkgs.vicinae}/bin/vicinae open
        bind = $mod, Space, exec, ${pkgs.vicinae}/bin/vicinae open
        bind = $mod SHIFT, V, exec, ${pkgs.vicinae}/bin/vicinae 'vicinae://launch/clipboard/history?toggle=true'
        bind = $mod SHIFT, W, exec, ${wallpaperScript}/bin/hypr-shell-wallpaper random
        bind = , F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot area
        bind = SHIFT, F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot full
        bind = CTRL, F6, exec, ${screenshotScript}/bin/hypr-shell-screenshot window
        bind = $mod, E, exec, ${pkgs.nautilus}/bin/nautilus
        bind = $mod, Q, exec, ${popupScript}/bin/hypr-shell-popup quick-settings
        bind = $mod, N, exec, ${pkgs.networkmanagerapplet}/bin/nm-connection-editor
        bind = $mod, B, exec, ${pkgs.blueman}/bin/blueman-manager
        bind = $mod, M, exec, ${pkgs.mission-center}/bin/missioncenter
        bind = $mod, Escape, exec, ${unstable.hyprshutdown}/bin/hyprshutdown
        bind = , XF86PowerOff, exec, ${unstable.hyprshutdown}/bin/hyprshutdown
        bind = $mod, L, exec, ${pkgs.systemd}/bin/loginctl lock-session
        bind = $mod SHIFT, Q, killactive,
        bind = $mod, F, fullscreen,
        bind = $mod, V, togglefloating,

        bindm = $mod, mouse:272, movewindow
        bindm = $mod, mouse:273, resizewindow

        bind = $mod, 1, workspace, 1
        bind = $mod, 2, workspace, 2
        bind = $mod, 3, workspace, 3
        bind = $mod, 4, workspace, 4
        bind = $mod, 5, workspace, 5
        bind = $mod SHIFT, 1, movetoworkspace, 1
        bind = $mod SHIFT, 2, movetoworkspace, 2
        bind = $mod SHIFT, 3, movetoworkspace, 3
        bind = $mod SHIFT, 4, movetoworkspace, 4
        bind = $mod SHIFT, 5, movetoworkspace, 5
      '';

    };

    services.hyprpolkitagent.enable = true;

    services.hyprsunset = {
      enable = true;
      settings = {
        profile = [
          {
            time = "7:00";
            identity = true;
          }
          {
            time = "19:00";
            temperature = 5000;
          }
          {
            time = "22:00";
            temperature = 4200;
          }
        ];
      };
    };

    home.activation.ensureHyprShellDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.cacheHome}/hypr-shell" "${config.xdg.stateHome}/hypr-shell"
    '';

    systemd.user.services = {
      hypr-shell-swww = {
        Unit = {
          Description = "Hyprland wallpaper daemon";
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.swww}/bin/swww-daemon";
          Restart = "on-failure";
        };
      };

      hypr-shell-wallpaper = {
        Unit = {
          Description = "Apply Hyprland shell wallpaper";
          After = [ "hypr-shell-swww.service" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${wallpaperScript}/bin/hypr-shell-wallpaper restore";
          Environment = [ "WALLPAPERS_DIR=${wallpapersDir}" ];
        };
      };

      hypr-shell-quickshell = {
        Unit = {
          Description = "Minimal Hyprland Quickshell";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.quickshell}/bin/quickshell --config hyprland";
          Restart = "on-failure";
          Environment = [ "WALLPAPERS_DIR=${wallpapersDir}" ];
        };
      };

      hypr-shell-vicinae = {
        Unit = {
          Description = "Vicinae launcher service";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server";
          Restart = "on-failure";
          Environment = [
            "USE_LAYER_SHELL=1"
            "WALLPAPERS_DIR=${wallpapersDir}"
          ];
        };
      };

      # hypr-shell-clipboard = {
      #   Unit = {
      #     Description = "Clipboard history collector";
      #     After = [ "graphical-session.target" ];
      #     PartOf = [ "graphical-session.target" ];
      #   };
      #
      #   Service = {
      #     ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      #     Restart = "on-failure";
      #   };
      # };
    };
  };
}
