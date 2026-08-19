{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.hyprland;
in
{
  options.local.hyprland = {
    enable = lib.mkEnableOption "Hyprland system configuration";
  };

  config = lib.mkIf cfg.enable {
    # This enables the compositor package, the Hyprland session files, and
    # XWayland support for older apps that still speak X11.
    programs.hyprland = {
      enable = true;
      xwayland = {
        enable = true;
        force_zero_scaling = true; # Have XWayland apps scale correctly under Wayland
      };
    };

    # Force XWayland apps to use Wayland to avoid some pixalation issues
    # Helps Chromium/Electron apps prefer Wayland behavior under NixOS.
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    # Nautilus and other GTK/GNOME apps store settings in dconf. GNOME enables
    # this automatically; a standalone Hyprland session needs it explicitly.
    programs.dconf.enable = true;

    # Login screen replacement for GDM in the Hyprland profile.
    #
    # `start-hyprland` is upstream's launch wrapper (shipped in the hyprland
    # package). It prepares the session environment (XDG vars, D-Bus/systemd
    # activation-environment imports) that xdg-desktop-portal and screen
    # sharing depend on; launching the bare `Hyprland` binary skips that and
    # makes recent Hyprland versions warn at startup.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${config.programs.hyprland.package}/bin/start-hyprland";
        user = "greeter";
      };
    };

    # This does not install hyprlock or hypridle. It only allows a PAM service
    # named `hyprlock` to authenticate the user at the lock screen. The actual
    # lock/idle programs are configured in Home Manager.
    security.pam.services = {
      hyprlock = { };

      greetd.enableGnomeKeyring = true;
    };

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
