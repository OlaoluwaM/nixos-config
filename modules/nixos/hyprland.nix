{
  config,
  lib,
  pkgs,
  inputs,
  unstable,
  ...
}:
let
  cfg = config.local.hyprland;
  # Chosen once in lib/hyprland-source.nix, shared with Home Manager.
  hyprlandPackages = import ../../lib/hyprland-source.nix { inherit inputs unstable pkgs; };
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
      # Both from the same set, so the compositor and portal stay built against each other
      package = hyprlandPackages.hyprland;
      portalPackage = hyprlandPackages.xdg-desktop-portal-hyprland;
      xwayland = {
        enable = true;
      };
    };

    # The system mesa deliberately stays on 26.05's, even though the flake's
    # Hyprland links against nixos-unstable's. The Hyprland wiki suggests
    # moving hardware.graphics.package to Hyprland's mesa to avoid lag in
    # GPU-heavy apps (https://github.com/hyprwm/Hyprland/issues/5148), but
    # that driver is built for unstable's newer glibc (it needs GLIBC_2.43),
    # and every program built from stable nixpkgs (Quickshell, kitty, ...)
    # then fails to load it: no OpenGL, so no bar and no greeter. A stable
    # driver loads in Hyprland too, since glibc is backward compatible.

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
