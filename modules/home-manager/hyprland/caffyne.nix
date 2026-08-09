{
  config,
  inputs,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.hyprland;
  caffyneEnabled = cfg.enable && cfg.shell.backend == "caffyne";
  hyprlandSessionTarget = config.wayland.systemd.target;
  system = pkgs.stdenv.hostPlatform.system;

  upstreamCaffynePackage = inputs.caffyne.packages.${system}.default;
  caffynePackage = upstreamCaffynePackage.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./caffyne-vicinae-only.patch
      ./caffyne-runtime-integration.patch
      ./caffyne-hypridle-hyprlock.patch
    ];

    # lockscreen.py and services/idle.py are dead code: nothing in the
    # patched tree imports either (verified). But Fabric registers an
    # org.Fabric.fabric.Execute D-Bus method that is exec(source, ...)
    # against main.py's live namespace, callable by anything on the user's
    # session bus, and this profile's own keybind wrapper (caffyneAction,
    # defined below) depends on that same method existing. As long
    # as the files are present on disk, a caller on that bus could still do
    # `Execute("import lockscreen; lockscreen.lock()")` and reach the native
    # PAM lock path documented in CAFFYNE-NATIVE-AUTH-ISSUES.md -- not a
    # privilege escalation (such a caller already runs as the user), but a
    # foot-gun worth removing outright rather than leaving merely
    # unreferenced. Deleting the files makes `import lockscreen` fail, so
    # the native auth path is actually gone, not just dead code.
    postPatch = (old.postPatch or "") + ''
      rm -f lockscreen.py services/idle.py
    '';
  });
  caffyneSource = inputs.caffyne;
  caffyneConfigRoot = "${config.xdg.configHome}/caffyne-shell";

  # Fabric exposes the same Execute method used by fabric-cli over D-Bus. Keep
  # the local wrapper intentionally narrow so Hyprland keybindings can invoke
  # only the Caffyne actions owned by this profile.
  caffyneAction = pkgs.writeShellApplication {
    name = "hypr-shell-caffyne-action";
    runtimeInputs = [
      pkgs.glib
      pkgs.systemd
    ];
    text = ''
      action="''${1:-}"

      case "$action" in
        settings)
          source="bar_manager.toggle('Settings')"
          ;;
        wifi)
          source="bar_manager.toggle('Wifi')"
          ;;
        bluetooth)
          source="bar_manager.toggle('Bluetooth')"
          ;;
        session)
          source="bar_manager.toggle('Session')"
          ;;
        wallpapers)
          source="bar_manager.toggle('Wallpapers')"
          ;;
        notifications)
          source="bar_manager.toggle('Notifications')"
          ;;
        *)
          echo "usage: hypr-shell-caffyne-action {settings|wifi|bluetooth|session|wallpapers|notifications}" >&2
          exit 64
          ;;
      esac

      exec gdbus call \
        --session \
        --dest org.Fabric.fabric.caffyne-shell \
        --object-path /org/Fabric/fabric \
        --method org.Fabric.fabric.Execute \
        "$source"
    '';
  };

  defaultBar = {
    alignment = "bottom";
    floating_bar = false;
    floating_applets = true;
    rounded_edges = true;
    min_width = false;
    auto_hide = false;
    left = [
      "Dash"
      {
        widget = "Processes";
        variant = "scale";
      }
      "Weather"
      "Media"
    ];
    center = [ "Dock" ];
    right = [
      "Tray"
      "Calendar"
      {
        widget = "Clock";
        variant = "icon+label";
      }
      {
        widget = "Settings";
        variant = "single";
      }
      "Notifications"
    ];
  };

  caffyneConfigSeed = (pkgs.formats.json { }).generate "caffyne-config-seed.json" {
    bars.configs = [
      {
        monitor = 0;
        bars = [ defaultBar ];
        alignment = "bottom";
        floating_bar = true;
      }
    ];

    # Use the stable Home Manager path instead of persisting a versioned Nix
    # store path when Caffyne first saves its mutable configuration.
    wallpaper.path = "${caffyneConfigRoot}/wallpapers/wall14.jpg";
  };

  mutableStyleFiles = [
    "borders.css"
    "colors.css"
    "fonts.css"
  ];
  styleDirectory = builtins.readDir "${caffyneSource}/style";
  staticStyleFiles = lib.filter (
    name: styleDirectory.${name} == "regular" && !(builtins.elem name mutableStyleFiles)
  ) (builtins.attrNames styleDirectory);
  staticStyleConfig = builtins.listToAttrs (
    map (name: {
      name = "caffyne-shell/style/${name}";
      value.source = "${caffyneSource}/style/${name}";
    }) staticStyleFiles
  );

  # The upstream Nix wrapper currently includes swww even though Caffyne's
  # wallpaper service calls awww. Supply every externally executed command
  # through the service environment without patching or forking Caffyne.
  #
  # No wlsunset here: night_mode.py no longer spawns it directly. Night light
  # is now systemd-owned services.hyprsunset (see default.nix), and Caffyne's
  # night-mode tile only shells out to `systemctl --user start/stop
  # hyprsunset.service`, the same "Caffyne owns UI, systemd owns lifecycle"
  # split already used for the Caffeine tile. pkgs.systemd below already
  # covers that.
  caffyneRuntimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.bluez
    pkgs.brightnessctl
    pkgs.coreutils
    pkgs.ddcutil
    pkgs.git
    pkgs.glib
    pkgs.hyprland
    pkgs.matugen
    pkgs.networkmanager
    pkgs.pipewire
    pkgs.playerctl
    pkgs.procps
    pkgs.pulseaudio
    pkgs.systemd
    pkgs.util-linux
    pkgs.wf-recorder
    pkgs.wireplumber
    unstable.awww
    cfg.commands.caffeineScript
  ];
in
{
  config = lib.mkIf caffyneEnabled {
    local.hyprland.commands.caffyneAction = caffyneAction;

    home.packages = [
      caffyneAction
      caffynePackage
      pkgs.matugen
    ];

    # Caffyne writes colors, borders and font choices at runtime. Keep those
    # three files mutable while managing the rest of upstream's style tree as
    # versioned links. Themes and bundled wallpapers are read-only inputs.
    xdg.configFile = staticStyleConfig // {
      "caffyne-shell/themes".source = "${caffyneSource}/themes";
      "caffyne-shell/wallpapers".source = "${caffyneSource}/wallpapers";
    };

    home.activation.seedCaffyneConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_root=${lib.escapeShellArg caffyneConfigRoot}
      config_file="$config_root/config/config.json"

      ${pkgs.coreutils}/bin/mkdir -p \
        "$config_root/config" \
        "$config_root/plugins" \
        "$config_root/style" \
        "$config_root/templates"

      # Use -s (non-empty), not -e (exists), as the re-seed guard. A truncated
      # or otherwise zero-byte config.json would otherwise be permanently
      # stuck: jq below exits 0 on empty input with empty output, cmp -s calls
      # that "identical" to the original, the temp file gets removed, and this
      # guard would never fire again to restore a real config.
      if [ ! -s "$config_file" ]; then
        ${pkgs.coreutils}/bin/install -m 0600 ${caffyneConfigSeed} "$config_file"
      fi

      # Vicinae is the only launcher in this profile. Preserve every other
      # runtime edit while removing Launcher entries from an existing Caffyne
      # config as well as from the seed above.
      launcher_free_config="$config_file.hm-vicinae-only"
      # `// []` on each section guards a bar object that is missing left,
      # center, or right entirely: without it, map(select(...)) over null
      # aborts the whole filter ("Cannot iterate over null", exit 5), and this
      # falls through to the warning branch below and leaves Launcher entries
      # in place instead of just treating the missing section as empty.
      #
      # `[ -s "$launcher_free_config" ]` after the jq call closes a second
      # gap: a whitespace-only config.json (e.g. a few stray spaces) passes
      # the `[ -s "$config_file" ]` re-seed guard above (it is not zero
      # bytes), but jq reads zero JSON values from it and exits 0 with truly
      # empty output. Without this check, cmp would see that empty temp file
      # as "different" from the real one and mv it into place, zeroing
      # config.json for the rest of this session. `jq -e .` was considered
      # instead of this, but it also treats a literal top-level `null` as a
      # failure (its -e flag exits 1 on a `false`/`null` result, not just on
      # a parse error), which would misfire on that otherwise-valid case.
      if ${pkgs.jq}/bin/jq '
        (.bars.configs[]?.bars[]? | .left, .center, .right) |=
          ((. // []) | map(select(
            if type == "string" then
              . != "Launcher"
            else
              .widget? != "Launcher"
            end
          )))
      ' "$config_file" > "$launcher_free_config" && [ -s "$launcher_free_config" ]; then
        # cmp comes from diffutils, not coreutils. Pointing this at the
        # coreutils output instead still evaluated and built fine, but produced
        # a path that does not exist, so the test always failed with "command
        # not found" and every activation took the rewrite branch below --
        # harmless, but it reformatted config.json on each home-manager switch
        # and widened the window for that write to race a live Caffyne
        # user_options.save().
        if ${pkgs.diffutils}/bin/cmp -s "$config_file" "$launcher_free_config"; then
          ${pkgs.coreutils}/bin/rm -f "$launcher_free_config"
        else
          ${pkgs.coreutils}/bin/chmod 0600 "$launcher_free_config"
          ${pkgs.coreutils}/bin/mv "$launcher_free_config" "$config_file"
        fi
      else
        ${pkgs.coreutils}/bin/rm -f "$launcher_free_config"
        echo "warning: could not remove Caffyne Launcher entries from $config_file" >&2
      fi

      ${lib.concatMapStringsSep "\n" (name: ''
        if [ ! -e "$config_root/style/${name}" ]; then
          ${pkgs.coreutils}/bin/install -m 0644 ${caffyneSource}/style/${name} "$config_root/style/${name}"
        fi
      '') mutableStyleFiles}
    '';

    systemd.user.services.caffyne-shell = {
      Unit = {
        Description = "Caffyne desktop shell";
        After = [
          hyprlandSessionTarget
          "caffyne-awww.service"
        ];
        # Order after awww but do not hard-require it: awww's own
        # Restart=on-failure/RestartSec=1 can hit systemd's default
        # DefaultStartLimitBurst=5 within DefaultStartLimitIntervalSec=10s (five
        # failures in ~5s), which lands caffyne-awww in "failed". A Requires=
        # here would then stop or refuse to (re)start the whole shell over a
        # wallpaper-daemon hiccup. The runtime patch already makes Caffyne
        # degrade gracefully (skips the initial wallpaper apply) when awww
        # isn't ready, so Wants= + After= gives the same startup ordering
        # without coupling the shell's availability to awww's.
        Wants = [ "caffyne-awww.service" ];
        PartOf = [ hyprlandSessionTarget ];
        # Starting Caffyne also retires processes left behind by the previous
        # Quickshell generation. Home Manager defaults
        # systemd.user.startServices to true, which uses sd-switch to stop
        # units that disappear from the generation during a backend switch, so
        # this Conflicts= list is not what makes that happen. Keep it anyway as
        # defence-in-depth against a leftover running instance if that
        # mechanism is ever disabled or misses a unit.
        Conflicts = [
          "hypr-shell-awww.service"
          "hypr-shell-quickshell.service"
          "hypr-shell-waypaper-restore.service"
        ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = lib.getExe caffynePackage;
        Environment = [
          "PATH=${caffyneRuntimePath}"
          "PYTHONUNBUFFERED=1"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # Keep awww under systemd rather than as a Caffyne child. Caffyne waits for
    # `awww query` before its first apply; systemd restarts the daemon if it dies
    # and stops it when the Hyprland target is stopped or the backend changes.
    systemd.user.services.caffyne-awww = {
      Unit = {
        Description = "Caffyne awww wallpaper daemon";
        # Match caffyne-shell's ordering: without this, sd-switch/systemd is
        # free to start awww before the Hyprland session target is up, which
        # is pointless (there is no compositor yet to hand a wallpaper to).
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
        Conflicts = [ "hypr-shell-awww.service" ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = "${unstable.awww}/bin/awww-daemon";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
