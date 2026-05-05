# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/nixos/configuration.nix
# Host: Asus ROG Zephyrus M16 (2023)
{
  inputs,
  lib,
  config,
  hostConfig,
  pkgs,
  ...
}:
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
    olaolu = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      # initialPassword = "correcthorsebatterystaple";
      isNormalUser = true;
      description = "Olaoluwa Mustapha";
      openssh.authorizedKeys.keys = [
        # Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # NOTE: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];
      shell = pkgs.zsh;
    };
  };

  # Install Firefox
  programs.firefox.enable = true;

  # Install ZSH
  programs.zsh.enable = true;

  # Enable docker
  virtualisation.docker.enable = true;

  # Enable GNUpg Agent
  programs.gnupg.agent.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is installed by default.
    wget
    curl
    memtest86plus
  ];

  # Necessary as described here: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enableCompletion
  environment.pathsToLink = [ "/share/zsh" ];

  # NixOS automatic upgrades. This is the system-level updater: it builds a new
  # version of the operating system using the package versions already recorded
  # in flake.lock. It does not choose newer package versions itself; Home
  # Manager does that part. See README.md for the split.
  # Reference: https://wiki.nixos.org/wiki/Automatic_system_upgrades
  # This creates and enables a systemd timer for automatic updates
  system.autoUpgrade = {
    # Turn on the scheduled system update job.
    enable = true;

    # Tell the updater where this repo lives and which machine config to build.
    # "#boreas" means "use the boreas machine from flake.nix".
    flake = ""; # Something like "/home/olaolu/Desktop/labs/nix-setup#boreas";

    # Build the update now, but only start using it after the next reboot. This
    # avoids changing the running desktop session while we're using it.
    operation = "boot";

    # Run every Saturday at 5 PM. systemd uses 24-hour time.
    dates = "Sat 17:00";

    # Allow systemd to delay the job by up to 45 minutes. This avoids every
    # scheduled job on the machine starting at the exact same second.
    randomizedDelaySec = "45min";

    # If the laptop was off at 5 PM Saturday, run the missed update later when
    # the machine is back on instead of skipping the week.
    persistent = true;

    # Never restart the machine automatically. If the update needs a reboot, it
    # waits until you reboot manually.
    allowReboot = false;

    # Avoid adding nixos-rebuild's legacy --upgrade flag. In this flake setup.
    # --upgrade is useful for channel-based setup, but since we're using flakes, it is redundant.
    #
    # Home Manager is responsible for editing flake.lock; this timer only rebuilds the system from the lockfile that already exists.
    # This means that this timer would need to run *after* the HM auto-upgrade timer.
    upgrade = false;

    # Keep detailed build output in the logs so failures are easier to diagnose.
    # Do not include flake update flags here because we don't want the systemd timer to update our flake.lock. Doing so might lead to unexpected outcomes since the timer runs as root but the flake.lock is owned by a user
    flags = [ "-L" ];
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
  system.stateVersion = "25.11";
}
