# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/home-manager/home.nix
{
  inputs,
  hostConfig,
  lib,
  config,
  pkgs,
  unstable,
  ...
}:
let
  home = config.home.homeDirectory;
  visual = "nvim";
  dev = "${config.xdg.userDirs.desktop}/${hostConfig.devDirname}";
in
{
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../modules/home-manager/desktop.nix
    ../../modules/home-manager/dotfiles.nix
    ../../modules/home-manager/fs-layout.nix
    ../../modules/home-manager/zsh.nix
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
      (final: prev: {
        cheat = prev.cheat.overrideAttrs (old: {
          version = "5.1.0";
          src = prev.fetchFromGitHub {
            owner = "cheat";
            repo = "cheat";
            rev = "5.1.0";
            hash = lib.fakeHash; # TODO: Fake hash, nix will give you the right one to replace this with
          };
        });
      })

      (final: prev: {
        defuddle = unstable.defuddle.overrideAttrs (old: {
          version = "0.18.1";
          src = prev.fetchFromGitHub {
            owner = "kepano";
            repo = "defuddle";
            rev = "0.18.1";
            hash = lib.fakeHash; # TODO: Fake hash, nix will give you the right one to replace this with
          };
        });
      })

    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    username = "olaolu";
    homeDirectory = home;
    sessionVariables = {
      VISUAL = visual;
      EDITOR = visual;
      DEV = dev;
      GIT_PAGER = "delta";
      COMPOSE_BAKE = "true";
    };
  };

  # Add stuff for your user as you see fit:
  # Doing this mean home-manager will be the one to manage your configuration for the program in question
  # programs.neovim.enable = true;
  home.packages = with pkgs; [
    # Packages from stable channel
    acpi
    atool

    bat
    bat-extras.core
    bitwarden-desktop
    bottom

    cmake
    cheat # Uses overlay
    claude-code # From https://github.com/sadjow/claude-code-nix
    codex # From https://github.com/sadjow/codex-cli-nix

    defuddle # Uses overlay
    direnv
    duf

    expect

    fish
    fdupes

    gapless
    git-extras
    glmark2
    gnumake
    gnupg
    google-chrome

    haskellPackages.threadscope
    (callPackage ../../pkgs/hacker-laws-cli { })

    libappindicator
    libpq
    libwebp
    localsend

    meson

    nmap
    nixfmt
    nitch
    nvtopPackages.nvidia
    nvtopPackages.intel
    # Add amd on an amd device

    openssl
    ookla-speedtest

    pandoc
    playerctl
    pgcli
    protobuf
    protonvpn-gui
    powertop

    racket
    (callPackage ../../pkgs/rxfetch { })

    slack
    spotify

    texliveFull
    typescript
    typst

    vlc

    wirelesstools
    wl-clipboard
    woff2

    z3

    # Packages from unstable channel
    unstable.atuin

    unstable.cabal-install
    unstable.cabal2nix

    unstable.delta
    unstable.discord

    unstable.fastfetch
    unstable.fd
    unstable.fend
    unstable.ffmpeg-full
    unstable.ffmpegthumbnailer
    unstable.fx
    unstable.fzf

    unstable.gdu
    unstable.git-credential-manager
    # Override example to add plugins, you can do this for any package
    (unstable.git.override {
      withSsh = true;
      withLibsecret = true;
    })
    unstable.gh
    unstable.go

    unstable.httpie

    unstable.imagemagick
    unstable.inxi
    unstable.python3Packages.ipython

    unstable.jql
    unstable.just
    unstable.just-lsp

    unstable.kitty

    unstable.libdrm
    unstable.lazydocker
    unstable.lazygit
    unstable.libgcc
    unstable.libva
    unstable.libva-utils
    unstable.lld
    unstable.lsd
    unstable.lsof

    unstable.navi
    unstable.ncdu
    unstable.neovim
    unstable.neovim-node-client
    unstable.nil
    (callPackage ../../pkgs/notebooklm-mcp-cli { })
    unstable.noti

    unstable.obsidian
    unstable.openai-whisper

    unstable.pavucontrol
    unstable.perl
    unstable.pciutils
    unstable.pinentry-curses
    unstable.procs
    unstable.proton-vpn-cli
    # withPackages wraps python3 so these libraries are importable by the interpreter.
    # Again we are installing pynvim and dnspython this way because they are libraries not standalone executables.
    # Yes there are individual entries for them in nixpkgs but they wouldn't be useful when specified in that way
    (unstable.python3.withPackages (ps: [
      ps.pynvim
      ps.dnspython
    ]))

    unstable.rainfrog
    unstable.rip2
    unstable.ripgrep
    unstable.ripgrep-all
    unstable.rlwrap

    unstable.sad
    unstable.sd
    unstable.shellcheck
    unstable.shfmt
    unstable.socat
    unstable.stack
    unstable.stack2nix
    unstable.starship

    unstable.tealdeer
    unstable.termdown
    unstable.tinyxxd
    unstable.tre-command

    unstable.uv

    unstable.virt-manager
    unstable.virt-viewer
    unstable.vscode-fhs

    unstable.w3m
    unstable.webp-pixbuf-loader
    unstable.witr

    unstable.yazi
    unstable.yt-dlp

    unstable.zoxide
  ];

  services.flatpak = {
    enable = true;
    packages = [
      "io.ente.auth"
      "im.riot.Riot"
      "it.mijorus.gearlever"
      "com.bilingify.readest"
      "io.github.flattool.Warehouse"
      "com.github.tchx84.Flatseal"
    ];
    update.auto = {
      enable = true;
      onCalendar = "Fri 10:00";
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Manage standard XDG dirs with HM, and create them if they don't exist. Also supports non-standard dirs via the `extra` option.
  # This sets the following env variables by default:
  #   XDG_CONFIG_HOME = ~/.config
  #   XDG_DATA_HOME   = ~/.local/share
  #   XDG_STATE_HOME  = ~/.local/state
  #   XDG_CACHE_HOME  = ~/.cache
  # We access them using config.xdg.configHome, config.xdg.dataHome, etc. in the rest of our config.
  xdg = {
    enable = true;

    userDirs = {
      enable = true;
      createDirectories = true;
      # The Desktop, Documents, Videos, Pictures xdg dirs have the right defaults: https://github.com/nix-community/home-manager/blob/a89686d115e970e200eb2caa7603f3673050e00c/modules/misc/xdg-user-dirs.nix#L178
    };
  };

  # Enable dotfiles
  local.dotfiles = {
    enable = true;
    dotsPath = "${config.xdg.userDirs.desktop}/${hostConfig.dotfilesRelativePath}";
  };

  # Enable and configure zsh with OMZ and our custom module
  local.zsh = {
    enable = true;
    zshrcConfigPath = "${home}/.zshrc.nix.zsh";
    histFilePath = "${config.local.dotfiles.dotsPath}/shell/.zsh_history";
  };

  local.desktop.profile = hostConfig.desktopProfile;

  # Home Manager automatic upgrades. This is the user-level updater: it first
  # refreshes flake.lock so the repo points at newer package versions, then it
  # updates user tools and dotfiles. NixOS later uses the same lockfile
  # for the operating-system update. See README.md for the split.
  services.home-manager.autoUpgrade = {
    # Turn on the scheduled Home Manager update job.
    enable = true;

    # Run every Saturday at 9 AM. systemd uses 24-hour time.
    frequency = "Sat 09:00";

    # Use the repo's flake.nix for Home Manager instead of the older
    # channel-based setup.
    useFlake = true;

    # Refresh flake.lock before applying the Home Manager config. This is what
    # actually moves the repo to newer package versions.
    preSwitchCommands = [ "nix flake update" ];

    # The folder containing this repo's flake.nix. The timer enters this folder
    # before refreshing flake.lock and applying the Home Manager config.
    flakeDir = ""; # Something like "/home/olaolu/Desktop/labs/nixos-config"

    # Keep detailed build output in the logs so failures are easier to diagnose.
    flags = [ "-L" ];
  };

  programs.obs-studio = {
    enable = true;

    package = (
      unstable.obs-studio.override {
        cudaSupport = (hostConfig.gpu or null) == "nvidia";
      }
    );

    plugins = with unstable.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi
      obs-gstreamer
      obs-vkcapture
      obs-noise
      obs-aitum-multistream
    ];
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
