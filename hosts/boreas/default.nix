# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/nixos/configuration.nix
# Host: Asus ROG Zephyrus M16 (2023)
# TODO: Update relevant configuration once we have a bare metal installation of nixos
{
  inputs,
  lib,
  config,
  unstable,
  hostConfig,
  pkgs,
  ...
}:
let
  inherit (hostConfig)
    username
    userFullName
    ;

  # boreas runs both on bare metal (with a real NVIDIA GPU) and as a QEMU/KVM
  # guest used to test this config, where no GPU is passed through. Gate all the
  # NVIDIA bits on the host's declared GPU so the VM rebuild doesn't try to run
  # the CDI generator (which probes NVML and fails with "Driver Not Loaded").
  # Mirrors the same flag the home-manager config already uses.
  hasNvidiaGpu = (hostConfig.gpu or null) == "nvidia";
in
{
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
    ../../modules/nixos/desktop.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
    };
    # Opinionated: disable channels
    channel.enable = false;
  };

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  # Enable memtest
  # boot.loader.systemd-boot.memtest86.enable = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Literal value because of the directory path. This is under the "boreas" host so making it variable doesn't make sense
  networking.hostName = "boreas";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  local.desktop.profile = hostConfig.desktopProfile;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # NOTE: You can configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # You can add more user entries here if you want to. They'll all follow the same schema as "olaolu"
    ${username} = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      # initialPassword = "correcthorsebatterystaple";
      isNormalUser = true;
      description = userFullName;
      openssh.authorizedKeys.keys = [
        # Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # NOTE: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
        "libvirtd"
      ];
      shell = pkgs.zsh;
    };
  };

  # Install Firefox
  programs.firefox.enable = true;

  # Install ZSH
  programs.zsh.enable = true;

  # Enable docker. CDI is only useful with the NVIDIA container toolkit, so it's
  # gated on the GPU too — otherwise dockerd advertises a feature nothing backs.
  virtualisation.docker = {
    enable = true;
    daemon.settings.features = {
      cdi = hasNvidiaGpu;
    };
  };

  # Setup docker with nvidia & nvidia-container-toolkit.
  # Gated on hasNvidiaGpu so the CDI generator service isn't pulled in on the VM,
  # where it would fail to initialize NVML (no GPU passed through).
  hardware.nvidia-container-toolkit = lib.mkIf hasNvidiaGpu {
    enable = true;
    package = unstable.nvidia-container-toolkit;
  };

  # Use nvidia proprietary drivers
  hardware.nvidia = lib.mkIf hasNvidiaGpu {
    open = false;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    with pkgs;
    [
      vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is installed by default.
      wget
      curl
      memtest86plus
      spice-vdagent
      virt-viewer
    ]
    ++ lib.optional hasNvidiaGpu unstable.nvidia-container-toolkit;

  # All this spice stuff is to make this config viable on a VM guest. Specifically to allow for copy-pasting between host and guest
  # Though it looks like we still need to run spice-vdagent in the foreground for this all to work
  # Some of these are from https://nixos.wiki/wiki/Virt-manager
  services.spice-webdavd.enable = true;
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # Enable virt-manager
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # Necessary as described here: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enableCompletion
  environment.pathsToLink = [ "/share/zsh" ];

  # supergfxctl is deprecated; asusctl/asusd now owns ASUS firmware controls. Force this
  # off because older nixpkgs asusd modules may still enable supergfxd by default.
  # see: https://github.com/NixOS/nixpkgs/pull/517986
  services.supergfxd.enable = false;

  # asusd's platform profile switching is backed by power-profiles-daemon.
  services.power-profiles-daemon.enable = true;

  # Setup asusctl and rog-control-center (https://asus-linux.org/guides/nixos/)
  services = {
    asusd = {
      enable = true;

      package = unstable.asusctl;

      asusdConfig.text = ''
        (
            // Keep long-term battery charging capped at 80%.
            charge_control_end_threshold: 80,

            // 0 means "do not restore a separate base limit" on shutdown/power events.
            // This keeps the 80% limit persistent instead of treating it like a temporary
            // one-shot charge limit.
            base_charge_control_end_threshold: 0,

            // Replaces the old Fedora udev script that stopped nvidia-powerd on battery
            // and restarted it on AC. Dynamic Boost is useful on wall power, but it can
            // burn battery when unplugged.
            disable_nvidia_powerd_on_battery: true,

            // Escape hatches for custom scripts on power-source changes. Keep these empty
            // so asusd/asusctl owns power management without extra shell glue.
            ac_command: "",
            bat_command: "",

            // When asusd changes the ASUS platform profile, also update the CPU
            // energy_performance_preference. Without this, switching to Quiet/Performance
            // changes the firmware profile but leaves CPU energy bias untouched.
            platform_profile_linked_epp: true,

            // Native baseline for power-source changes. AC goes straight to Performance.
            // Battery starts at Balanced so unplugging does not over-throttle a healthy
            // battery; the timer below lowers it to Quiet when capacity is <= 35%.
            platform_profile_on_battery: Balanced,
            change_platform_profile_on_battery: true,
            platform_profile_on_ac: Performance,
            change_platform_profile_on_ac: true,

            // EPP mapping used when platform_profile_linked_epp is true.
            profile_quiet_epp: Power,
            profile_balanced_epp: BalancePower,
            profile_custom_epp: Performance,
            profile_performance_epp: Performance,

            // Leave per-profile ASUS firmware tunings at stock defaults for now. The old
            // Fedora setup changed profiles, not wattage/fan tuning tables.
            ac_profile_tunings: {
                Balanced: (
                    enabled: false,
                    group: {},
                ),
                Performance: (
                    enabled: false,
                    group: {},
                ),
                Quiet: (
                    enabled: false,
                    group: {},
                ),
            },
            dc_profile_tunings: {
                Balanced: (
                    enabled: false,
                    group: {},
                ),
                Quiet: (
                    enabled: false,
                    group: {},
                ),
                Performance: (
                    enabled: false,
                    group: {},
                ),
            },

            // Armoury firmware settings such as MUX mode, panel overdrive, Dynamic Boost,
            // and NVIDIA temp target are left imperative until we choose explicit policies.
            armoury_settings: {},
        )
      '';
    };
  };

  # Adds the battery-percentage behavior from the old Fedora tuned scripts, but
  # keeps ASUS Linux as the control plane by calling asusctl profile set.
  systemd.services.asus-battery-profile-threshold =
    let
      serviceUnitDependencies = [
        "asusd.service"
        "power-profiles-daemon.service"
      ];
    in
    {
      description = "Select ASUS platform profile based on battery threshold";

      # Together, `after` & `wants` express an ordered dependency relationship between this service and the "asusd" service and "power-profiles-daemon" service. Specifically, it expresses that this asus-battery-profile-threshold service requires that the two aforementioned units be started (`wants`) when trying to start this one and that they should have been started up "before" this one (`after`).
      after = serviceUnitDependencies;
      wants = serviceUnitDependencies;

      path = [
        unstable.asusctl
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.systemd
      ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        set -eu

        battery_dir=
        for candidate in /sys/class/power_supply/BAT*; do
          if [ -f "$candidate/capacity" ] && [ -f "$candidate/status" ]; then
            battery_dir="$candidate"
            break
          fi
        done

        if [ -z "$battery_dir" ]; then
          systemd-cat -t asus-battery-profile-threshold -p warning echo "No battery found; skipping profile update"
          exit 0
        fi

        capacity="$(cat "$battery_dir/capacity")"
        status="$(cat "$battery_dir/status")"

        case "$status" in
          Charging|Full|Not\ charging)
            target=Performance
            ;;
          Discharging)
            if [ "$capacity" -le 35 ]; then
              target=Quiet
            elif [ "$capacity" -le 65 ]; then
              target=Balanced
            else
              target=Performance
            fi
            ;;
          *)
            systemd-cat -t asus-battery-profile-threshold -p warning echo "Unknown battery status '$status'; skipping profile update"
            exit 0
            ;;
        esac

        current="$(asusctl profile get | grep 'Active profile:' | sed 's/.*Active profile: //')"
        if [ "$current" = "$target" ]; then
          systemd-cat -t asus-battery-profile-threshold echo "ASUS profile already $target ($status, ''${capacity}%)"
          exit 0
        fi

        asusctl profile set "$target"
        systemd-cat -t asus-battery-profile-threshold echo "Set ASUS profile to $target ($status, ''${capacity}%)"
      '';
    };

  systemd.timers.asus-battery-profile-threshold = {
    description = "Periodically select ASUS platform profile from battery threshold";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "3min";
      Unit = "asus-battery-profile-threshold.service";
    };
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  #services.openssh = {
  #  enable = true;
  #  settings = {
  # Opinionated: forbid root login through SSH.
  #    PermitRootLogin = "no";
  # Opinionated: use keys only.
  # Remove if you want to SSH using passwords
  #     PasswordAuthentication = false;
  #   };
  # };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
