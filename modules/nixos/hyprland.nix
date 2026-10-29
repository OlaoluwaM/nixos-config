{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.local.hyprland;
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPackages = inputs.hyprland.packages.${system};
  # The nixos-unstable snapshot Hyprland's flake builds against (see the
  # hyprland input in flake.nix).
  hyprlandNixpkgs = inputs.hyprland.inputs.nixpkgs.legacyPackages.${system};
in
{
  options.local.hyprland = {
    enable = lib.mkEnableOption "Hyprland system configuration";
  };

  imports = [
    ./greet.nix
  ];

  config = lib.mkIf cfg.enable {

    # This enables the compositor package, the Hyprland session files, and
    # XWayland support for older apps that still speak X11.
    programs.hyprland = {
      enable = true;
      # Both from the flake input, so the compositor and portal stay built
      # against each other; the portal carries workspace sharing.
      package = hyprlandPackages.hyprland;
      portalPackage = hyprlandPackages.xdg-desktop-portal-hyprland;
      xwayland = {
        enable = true;
      };
    };

    # The flake's Hyprland links against nixos-unstable's mesa while this
    # system runs 26.05's, and that mismatch shows up as lag and FPS drops in
    # GPU-heavy apps (https://github.com/hyprwm/Hyprland/issues/5148). Move
    # the system mesa to Hyprland's snapshot to match. This changes the
    # Intel iGPU's userspace driver for every app, not just Hyprland; the
    # NVIDIA driver comes from the kernel packages and is unaffected.
    # enable32Bit is off on this host, so there is no package32 to sync.
    hardware.graphics.package = hyprlandNixpkgs.mesa;

    # Force XWayland apps to use Wayland to avoid some pixalation issues
    # Helps Chromium/Electron apps prefer Wayland behavior under NixOS.
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    # Nautilus and other GTK/GNOME apps store settings in dconf. GNOME enables
    # this automatically; a standalone Hyprland session needs it explicitly.
    programs.dconf.enable = true;
    local.greet.enable = lib.mkDefault true;

    # This does not install hyprlock or hypridle. It only allows a PAM service
    # named `hyprlock` to authenticate the user at the lock screen. The actual
    # lock/idle programs are configured in Home Manager.
    #
    # `silere-lock` does the same for silere-shell's own lock screen, which
    # authenticates under its own service name. Without it that lock comes up
    # but can never accept a password.
    security.pam.services = {
      hyprlock = { };
      silere-lock = { };
    };

    # hypridle holds suspend back until the session is locked (inhibit_sleep
    # in hypridle.nix) with a logind delay inhibitor, and logind ignores that
    # inhibitor after InhibitDelayMaxSec (5s by default). A cold start of the
    # shell's lock, its 3s confirmation window and a hyprlock fallback can
    # together take longer, so allow 10s.
    services.logind.settings.Login.InhibitDelayMaxSec = 10;

    # Nautilus uses GVfs for trash, removable devices, and common virtual file
    # systems. GNOME enables this for us; Hyprland does not.
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    # silere-shell's battery widget reads Quickshell.Services.UPower, which
    # talks to the system UPower daemon over D-Bus. GNOME pulls UPower in
    # implicitly; without it here, the shell sees no battery at all and the
    # bar pill never renders, on AC or on battery.
    services.upower.enable = true;

    # Same story for the shell's bluetooth pill and menu controls: they speak
    # to BlueZ over D-Bus via Quickshell.Bluetooth, and nothing else in this
    # profile pulls BlueZ in. Without it the adapter never appears and the
    # widget's availability gate keeps it hidden.
    hardware.bluetooth.enable = true;

    # Installs KDE Connect and opens its discovery/transfer port range
    # (1714-1764 TCP+UDP) in the firewall -- phone pairing is dead in the
    # water without the ports, and this module is the one place that owns
    # both halves. The session side (indicator + daemon on the Hyprland
    # session target) lives in home-manager/hyprland/modules/
    # session-services.nix; its SNI item surfaces in the shell's tray popup.
    programs.kdeconnect.enable = true;

    xdg.portal = {
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];

      config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];

        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
  };
}
