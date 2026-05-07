# Nixification Migration Checklist

Remaining items from [distro-setup](../distro-setup/) migration.

## Activation Scripts

- [ ] `notebooklm-mcp-cli` — `uv tool install`
- [ ] `claude-code` & `codex` — curl installer
- [ ] `gh` extensions: `gh-branch`, `gh-copilot`, `gh-download`, `gh-fire`, `gh-gitignore`, `gh-screensaver`, `gh-stashes`, `gh-tidy`
- [ ] npm globals via pnpm: `@openai/codex`, `dotfilers`, `tsx`, `typescript`, `neovim`
- [ ] GH aliases — `gh alias import` from aliases YAML

## Haskell

- [ ] GHCup / stack / HLS setup
- [ ] `hlint`, `implicit-hie`, `ghc-events`

## DE/WM Modules

Create modules under `modules/home-manager/` and `modules/nixos/`, then import from the user/host config.

```
modules/
  home-manager/
    gnome.nix        # GNOME user-level config (packages, flatpaks, dconf)
    hyprland.nix     # Hyprland user-level config
  nixos/
    gnome.nix        # GDM + GNOME system service
    hyprland.nix     # Hyprland system-level config
```

Import in `home/olaolu/default.nix`: `imports = [ ../../modules/home-manager/gnome.nix ];`
Import in `hosts/boreas/default.nix`: `imports = [ ../../modules/nixos/gnome.nix ];`
Swap imports to switch DE/WM. To add Cosmic, create `cosmic.nix` in both dirs.

### GNOME module (`modules/home-manager/gnome.nix`)

- [ ] GNOME-specific packages, flatpaks, and extensions — see [gnome-stuff.md](gnome-stuff.md)

### GNOME system module (`modules/nixos/gnome.nix`)

- [ ] Move GNOME/GDM/Wayland config out of `hosts/boreas/default.nix`

### Hyprland modules

- [ ] `modules/home-manager/hyprland.nix` — Hyprland user-level packages and config
- [ ] `modules/nixos/hyprland.nix` — Hyprland system-level config

## Dotfiles & Config

- [ ] Review and revise fedora and nixos dotfiles
- [ ] Dotfile symlinks — replace `symlinkDotfiles.sh` with `home.file` / `xdg.configFile`
- [ ] OBS config — `xdg.configFile."obs-studio".source = /path/to/dotfiles/obs-studio`
- [ ] AstroNvim — clone repo then `xdg.configFile."nvim".source = /path/to/nvim-setup`
- [ ] Zsh — symlink existing `.zshrc` via `home.file`, install OMZ + plugins via `home.activation` (don't use `programs.zsh` — it would override the dotfile)
- [ ] Cron jobs — replace `restoreCronjobs.sh` with `systemd.user.services` / `systemd.user.timers`
- [ ] Directory structure — `home.file` for XDG symlinks, `home.activation` for creating dirs

## System Config (`hosts/boreas/default.nix`)

- [ ] Nvidia container toolkit
- [ ] Nvidia drivers
- [ ] Asus ROG hardware (asusctl + supergfxctl)
- [ ] Power management
- [ ] SSD TRIM
- [ ] Firmware updates
- [ ] Bluetooth
- [ ] Hardware-accelerated video
- [ ] Auto upgrades (replaces `dnf5-automatic`)

```nix
# Asus ROG hardware — https://asus-linux.org/guides/nixos/
services.asusd = {
  enable = true;
  enableUserService = true;
};
services.supergfxd.enable = true;
systemd.services.supergfxd.path = [ pkgs.pciutils ];


# Hardware-accelerated video — Intel
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    intel-media-driver    # VA-API for Broadwell+ (iHD)
    intel-vaapi-driver    # VA-API for older Intel (i965)
    vpl-gpu-rt            # Intel Quick Sync Video
  ];
};

# Nvidia drivers — verify bus IDs with `lspci | grep -E "VGA|3D"`
hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  nvidiaSettings = true;
  prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    offload.enable = true;
  };
};
services.xserver.videoDrivers = [ "nvidia" ];

# Nvidia container toolkit
hardware.nvidia-container-toolkit.enable = true;

# Power management
services.thermald.enable = true;
services.power-profiles-daemon.enable = true;

# SSD TRIM
services.fstrim.enable = true;

# Firmware updates
services.fwupd.enable = true;

# Bluetooth
hardware.bluetooth.enable = true;
hardware.bluetooth.powerOnBoot = false;

# Auto upgrades
system.autoUpgrade = {
  enable = true;
  flake = "path:/home/olaolu/Desktop/labs/nixos-config#boreas";
  dates = "weekly";
};
```

## System Config for Framework 16 (AMD)

```nix
# Power management
services.power-profiles-daemon.enable = true;
services.fstrim.enable = true;
services.fwupd.enable = true;

# Bluetooth
hardware.bluetooth.enable = true;
hardware.bluetooth.powerOnBoot = false;

# Graphics — AMD
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    amdvlk
  ];
  extraPackages32 = with pkgs.pkgsi686Linux; [
    amdvlk
  ];
};
# Mesa RADV (open-source Vulkan) is included by default on NixOS

# Fingerprint reader (Framework 16 has one)
services.fprintd.enable = true;

# Auto upgrades
system.autoUpgrade = {
  enable = true;
  flake = "path:/home/olaolu/Desktop/labs/nixos-config#framework";
  dates = "weekly";
};
```

No `services.thermald` — that's Intel-only. AMD thermal management is handled by the kernel.
No Nvidia config needed unless you get the dGPU expansion bay module.

## nixos-hardware

Add as a flake input for hardware-specific optimizations:

```nix
# flake.nix
inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

# then in nixosConfigurations.boreas:
modules = [
  inputs.nixos-hardware.nixosModules.<module-name>
  ./hosts/boreas
];
```

**Asus ROG Zephyrus M16 2023 (boreas):**
No exact match (GU604 not in nixos-hardware yet). Closest is `asus-zephyrus-gu603h` (2022 M16) which sets up Intel CPU + Nvidia PRIME + laptop/SSD defaults. The bus IDs may differ on the GU604 — verify with `lspci | grep -E "VGA|3D"` before using. Alternatively, use the common modules directly:

```nix
inputs.nixos-hardware.nixosModules.common-cpu-intel
inputs.nixos-hardware.nixosModules.common-gpu-nvidia
inputs.nixos-hardware.nixosModules.common-pc-laptop
inputs.nixos-hardware.nixosModules.common-pc-ssd
```

**Framework 16 (future):**

```nix
inputs.nixos-hardware.nixosModules.framework-16-7040-amd
# or if you get the AI 300 series variant:
inputs.nixos-hardware.nixosModules.framework-16-amd-ai-300-series
# with Nvidia GPU module:
inputs.nixos-hardware.nixosModules.framework-16-amd-ai-300-series-nvidia
```
