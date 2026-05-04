# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/home-manager/home.nix
{
  inputs,
  lib,
  config,
  pkgs,
  unstable,
  ...
}:
let
  home = config.home.homeDirectory;
  dots = "${home}/Desktop/dotfiles/nixos/.config";
  visual = "nvim";
  dev = "${config.xdg.userDirs.desktop}/dev";
in
{
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
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
        obs-aitum-multistream = prev.stdenv.mkDerivation {
          pname = "obs-aitum-multistream";
          version = "1.0.7";
          src = prev.fetchFromGitHub {
            owner = "Aitum";
            repo = "obs-aitum-multistream";
            rev = "1.0.7";
            hash = lib.fakeHash; # TODO: Fake hash, nix will give you the right one to replace this with
          };
          nativeBuildInputs = [ prev.cmake ];
          buildInputs = [
            prev.obs-studio
            prev.qt6.qtbase
          ];
        };
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
    homeDirectory = "/home/olaolu";
    # TODO: Perhaps we should move this to our dotfiles module where we have `home.file` defined
    sessionVariables = {
      VISUAL = visual;
      EDITOR = visual;
      DEV = dev;
      DOTS = dots;
      SYS_BAK_DIR_UNDER_GIT = "${dots}/system";
      WALLPAPERS_DIR = "${config.xdg.userDirs.pictures}/wallpapers";
      NAVI_PATH = "${dots}/navi/cheat";
      NAVI_CONFIG_PATH = "${dots}/navi/config.yaml";
      ATUIN_CONFIG_DIR = "${dots}/atuin";
      _ZO_DATA_DIR = "${dots}/zoxide";
      TEALDEER_CONFIG_DIR = "${dots}/tldr";
      THEMES_DIR = "${config.xdg.dataHome}/themes";
      CUSTOM_BIN_DIR = "${home}/.local/bin";
      SYS_BAK_DIR_NOT_UNDER_GIT = "${home}/sys-bak";
      CUSTOM_MAN_PATH = "${config.xdg.dataHome}/man";
      FONT_DIR = "${config.xdg.dataHome}/fonts";
      STARSHIP_CONFIG = "${dots}/starship/starship.toml";
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
    cheat

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
    libva-utils
    libpq
    localsend

    meson

    nmap
    nixfmt
    nitch
    nodejs_25
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

    unstable.cargo-update
    unstable.cargo-binstall

    unstable.delta
    unstable.discord

    unstable.fastfetch
    unstable.fd
    unstable.fend
    unstable.ffmpeg-full
    unstable.fx
    unstable.fzf

    unstable.gdu
    unstable.git-credential-manager
    unstable.gh
    unstable.go

    unstable.httpie

    unstable.imagemagick
    unstable.inxi
    unstable.ipython

    unstable.jql
    unstable.just
    unstable.just-lsp

    unstable.kitty

    unstable.lazydocker
    unstable.lazygit
    unstable.lld
    unstable.lsd
    unstable.lsof

    unstable.navi
    unstable.ncdu
    unstable.neovim
    unstable.nil
    unstable.noti

    unstable.obsidian
    # Override example to add plugins, you can do this for any package
    (unstable.obs-studio.override {
      plugins = with unstable.obs-studio-plugins; [
        obs-gstreamer
        obs-vaapi
        obs-wlrobs
        obs-noise
        pkgs.obs-aitum-multistream # from your overlay
      ];
    })
    unstable.openai-whisper

    unstable.pciutils
    unstable.pinentry-curses
    unstable.pnpm
    unstable.procs
    unstable.proton-vpn-cli
    # withPackages wraps python3 so these libraries are importable by the interpreter
    (unstable.python3.withPackages (ps: [
      ps.pynvim
      ps.dnspython
    ]))

    unstable.rainfrog
    unstable.rip2
    unstable.ripgrep
    unstable.ripgrep-all
    unstable.rlwrap
    unstable.ruby
    unstable.rustup

    unstable.sad
    unstable.sd
    unstable.shellcheck
    unstable.shfmt
    unstable.socat
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
      onCalendar = "weekly";
    };
  };

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;

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

      desktop = "${home}/Desktop";
      documents = "${home}/Documents";
      download = "${home}/Downloads";
      music = "${home}/Music";
      pictures = "${home}/Pictures";
      videos = "${home}/Videos";
    };
  };

  # Enable and configure zsh with OMZ and our custom module
  local.zsh = {
    enable = true;
    localConfigPath = "${dots}/shell/.zshrc.nix.zsh";
    dotsConfigPath = dots;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
