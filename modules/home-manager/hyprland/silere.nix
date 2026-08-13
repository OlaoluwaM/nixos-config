{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Beginner orientation:
#
# silere-shell is the Quickshell/QML bar for this Hyprland profile. It is the
# only shell here -- there is no backend option to choose between, unlike the
# old Caffyne/Quickshell split this profile tore down. Everything below gates
# on local.hyprland.enable like the rest of the profile.
#
# This module runs the shell with stock upstream defaults from the user's
# fork (input `silere-shell`, custom-branch). Theming/config generation is
# future work; see the maintainer comment on `silereShellSrc` below.
let
  cfg = config.local.hyprland;
  hyprlandSessionTarget = config.wayland.systemd.target;

  # Plain copy of the same file set upstream's packaging/aur/PKGBUILD
  # installs (shell.qml, config, modules, services, assets, scripts -- see
  # that PKGBUILD's package() step). No build step, no patching: this is a
  # derivation instead of a direct `inputs.silere-shell` source reference
  # only because a later stage substitutes a Nix-rendered
  # GeneratedDefaults.qml into config/ at build time, and that substitution
  # needs an install phase to hook into.
  silereShellSrc = pkgs.stdenvNoCC.mkDerivation {
    pname = "silere-shell";
    version = inputs.silere-shell.shortRev or "unknown";
    src = inputs.silere-shell;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      dest="$out/share/silere-shell"
      install -dm755 "$dest"
      cp -a shell.qml config modules services assets scripts "$dest/"

      runHook postInstall
    '';
  };

  # Tools the shell shells out to by bare name, found by:
  #   grep -rhoE 'command\s*=\s*\[[^]]*\]|exec\(\[[^]]*' services modules
  # run against the silere-shell checkout, then following every
  # Quickshell.execDetached(...) call site it didn't catch (Compositor.qml,
  # ConfigStore.qml, HyprDispatch.qml, SystemTools.qml) and the bash -c
  # script bodies those processes spawn in turn (cat, awk, busctl, ...).
  # services/SystemTools.qml's optional-tool probe list is the authoritative
  # superset of everything the stock shell may ever reach for.
  #
  # Almost every Process/execDetached call spawns "bash" (often "bash", "-c",
  # ...) as the literal command name, so bash has to be resolvable too, not
  # just the coreutils it then calls out to.
  silereShellPath =
    lib.makeBinPath [
      pkgs.bash
      pkgs.brightnessctl
      pkgs.coreutils
      pkgs.inotify-tools # inotifywait: Screenshot.qml's underline-glow watcher
      pkgs.libnotify # notify-send
      pkgs.procps # pgrep/pkill: NightLight.qml's hyprsunset supervision
      pkgs.systemd # systemctl, loginctl, busctl
      pkgs.hyprsunset # NightLight.qml spawns "hyprsunset" by bare name
    ]
    # hyprctl is deliberately left out of the explicit list above: pkgs.hyprland
    # would drag a second copy of the compositor into the closure just to get
    # one binary, and this profile already installs Hyprland at the NixOS
    # level (programs.hyprland.enable in modules/nixos/hyprland.nix), which
    # lands hyprctl in /run/current-system/sw/bin -- the NixOS user-manager's
    # default PATH. Environment= below fully replaces this unit's PATH rather
    # than extending it, so that directory has to be appended explicitly to
    # keep hyprctl reachable.
    + ":/run/current-system/sw/bin";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      quickshell

      # Qt runtime support the QML shell needs to render under Wayland.
      qt6.qtwayland
      qt6.qtdeclarative
      qt6.qtsvg
      qt6.qtimageformats
      libsForQt5.qtwayland
    ];

    systemd.user.services.silere-shell = {
      Unit = {
        Description = "silere-shell Quickshell bar";
        # Without this ordering, systemd is free to start the shell before
        # Hyprland (and a Wayland display to connect to) is up, which burns
        # the unit's restart budget on early, unrecoverable failures.
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
      };

      Install.WantedBy = [ hyprlandSessionTarget ];

      Service = {
        ExecStart = "${lib.getExe' pkgs.quickshell "qs"} -p ${silereShellSrc}/share/silere-shell/shell.qml";
        Restart = "on-failure";
        Environment = [ "PATH=${silereShellPath}" ];
      };
    };
  };
}
