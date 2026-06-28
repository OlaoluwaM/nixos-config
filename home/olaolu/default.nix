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
  # Using a literal value here because it aligns with the path. Making it variable doesn't make sense
  username = "olaolu";
  home = "/home/${username}";
  visual = "nvim";
  dev = "${config.xdg.userDirs.desktop}/${config.local.fsLayout.devDirname}";
  hasNvidiaGpu = (hostConfig.gpu or null) == "nvidia";
in
{
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../modules/home-manager/atuin.nix
    ../../modules/home-manager/bat.nix
    ../../modules/home-manager/bottom.nix
    ../../modules/home-manager/delta.nix
    ../../modules/home-manager/desktop.nix
    ../../modules/home-manager/dotfiles.nix
    ../../modules/home-manager/fs-layout.nix
    ../../modules/home-manager/fontconfig.nix
    ../../modules/home-manager/fzf.nix
    ../../modules/home-manager/git.nix
    ../../modules/home-manager/gpg.nix
    ../../modules/home-manager/lazygit.nix
    ../../modules/home-manager/lsd.nix
    ../../modules/home-manager/yazi.nix
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
      # For https://github.com/kepano/defuddle
      (final: prev: {
        defuddle =
          let
            version = "0.18.1";
          in
          unstable.defuddle.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitHub {
              owner = "kepano";
              repo = "defuddle";
              rev = version;
              hash = "sha256-e/+eigIzpP0g+ZqTeyZnF6mloaY6UeKcMWfqryCcLbM=";
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
    username = username;
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

    bat-extras.core

    cmake
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
    nvtopPackages.full
    # Add amd on an amd device

    openssl
    ookla-speedtest

    pandoc
    playerctl
    pgcli
    protobuf
    proton-vpn
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
    unstable.bitwarden-desktop # Might fail due to electron_39 being used and deprecated

    unstable.cabal-install
    unstable.cabal2nix
    unstable.cheat # Creating an overlay would involve more effort than I am willing to expend

    unstable.discord

    unstable.fastfetch
    unstable.fd
    unstable.fend
    unstable.ffmpeg-full
    unstable.ffmpegthumbnailer
    unstable.fx

    unstable.gdu
    unstable.git-credential-manager
    # Override example to add plugins, you can do this for any package
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
    unstable.libgcc
    unstable.libva
    unstable.libva-utils
    unstable.lld
    unstable.lsof

    unstable.navi
    unstable.ncdu
    unstable.neovim
    unstable.neovim-node-client
    unstable.nil # For nix ide plugin
    unstable.nixd # For nix ide plugin
    (callPackage ../../pkgs/notebooklm-mcp-cli { })
    unstable.noti

    unstable.obsidian
    unstable.openai-whisper

    unstable.pavucontrol
    unstable.perl
    unstable.pciutils
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
    # stack2nix is marked broken in nixpkgs; use cabal2nix for simple
    # package expression generation, or haskell.nix for Stack/Stackage fidelity.
    # unstable.stack2nix
    unstable.starship

    unstable.tealdeer
    unstable.termdown
    unstable.tinyxxd
    unstable.tre-command

    unstable.uv

    unstable.vscode-fhs

    unstable.w3m
    unstable.webp-pixbuf-loader
    unstable.witr
    unstable.wireshark

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

  # Enable dotfiles. Must be done first so symlinks can be created for those configurations that depend on them
  local.dotfiles = {
    enable = true;
    dotsPath = "${config.xdg.userDirs.desktop}/${hostConfig.dotfilesRelativePath}";
  };

  local.atuin.enable = true;
  local.bat.enable = true;
  local.bottom.enable = true;
  local.delta.enable = true;
  local.fzf.enable = true;
  local.git.enable = true;
  local.lazygit.enable = true;
  local.lsd.enable = true;
  local.yazi.enable = true;

  local.fsLayout.devDirname = hostConfig.devDirname;

  # Enable and configure zsh with OMZ and our custom module
  local.zsh = {
    enable = true;
    zshrcConfigPath = "${home}/.zshrc.nix.zsh";
    # Keep shell history OUT of the dotfiles git tree — it can contain secrets,
    # and atuin already handles cross-machine history. Lives under XDG data.
    histFilePath = "${config.xdg.dataHome}/zsh/.zsh_history";
  };

  local.desktop.profile = hostConfig.desktopProfile;
  local.theme.preset = "catppuccin-mocha";

  programs.obs-studio = {
    enable = true;

    package = (
      unstable.obs-studio.override {
        cudaSupport = hasNvidiaGpu;
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
  home.stateVersion = "26.05";
}
