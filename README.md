# NixOS Setup

Based off the minimal startup config in [this repo](https://github.com/Misterio77/nix-starter-configs)

## Usage

> [!note]
> All `nixos-rebuild` or `home-manager` commands must reference the flake (using `--flake`) to work as you'd expect.

Clone this repo in the `$HOME` directory.

**Then for the first time only, following a fresh installation of NixOS, run the script `scripts/fresh-install-first-rebuild-switch.sh`. It will do two things:**

1. Refresh the `hardware-configuration.nix` module in `hosts/$HOST` so it aligns with what NixOS expects
2. Run `nixos-rebuild switch --flake ...`, which activates both the NixOS and Home Manager configurations.

Home Manager is integrated into the NixOS configuration, so every subsequent
`nixos-rebuild switch` also applies the user's Home Manager configuration:

- `sudo nixos-rebuild switch --flake $HOME/nixos-config#hostname`
- `sudo nixos-rebuild switch --flake "$HOME/nixos-config#hostname"`
- `sudo nixos-rebuild switch --flake ~/nixos-config#hostname`
- `cd ~/nixos-config` then run `sudo nixos-rebuild switch --flake .#hostname`

Make sure, regardless of the command you use, the NixOS switch passes successfully.

The first NixOS switch also installs the flake-pinned `home-manager` CLI in the
user's NixOS profile; no separate Home Manager initialization is required.
In other words, you can immediately start using the standalone home-manager cli to apply user-configuration changes if necessary:

```bash
home-manager switch -b hm-standalone-backup --flake .#$USER@$HOST
```

This repo intentionally uses a stable base with selected unstable packages:

- `nixpkgs` points at `nixos-26.05`.
- `home-manager` points at `release-26.05` and follows stable `nixpkgs`.
- `nixpkgs-unstable` is imported separately and passed in as `unstable` for specific packages that benefit from newer versions.

That keeps the NixOS and Home Manager module systems aligned while still allowing newer user packages where needed. This is the safer default for a daily-driver machine and is friendlier while learning Nix than running the whole config on unstable.

If we wanted to move Home Manager to `master`, we'd need to have Home Manager track nixpkgs-unstable. In `flake.nix`, this means changing `home-manager.url` to `github:nix-community/home-manager/master` and changing `home-manager.inputs.nixpkgs.follows` from `nixpkgs` to `nixpkgs-unstable`. For a fully unstable setup, we'd also make the standalone Home Manager `pkgs` come from `nixpkgs-unstable`.

### Applying changes

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#$HOST
```

This single command applies both layers in the correct order. Changes to session
environment variables may still require logging out and back in.

To apply only the user configuration, use the standalone Home Manager command
above.

## Using ROG Control Center on Boreas

ROG Control Center is the window for the `asusd` service. It starts in the
background when you sign in to GNOME or Hyprland.

Open it in one of these ways:

- press the ROG key;
- search for **ROG Control Center** in the app launcher;
- run `rog-control-center` in a terminal.

Closing the window leaves the app running in the tray. **Quit App** closes the
window and tray app, but `asusd` keeps running. Run `rog-control-center` again
to reopen it.

### What to change

| Page | What to use it for | Boreas rule |
| --- | --- | --- |
| System Control | Check temperatures, fan speeds, and the current power profile. | A manual profile change is temporary. The battery policy checks again every three minutes and when AC power changes. |
| Keyboard Aura | Preview or change keyboard lighting. | Permanent settings live in [`hosts/boreas/asusd/aura_19b6.ron`](hosts/boreas/asusd/aura_19b6.ron). |
| Fan Curves | Set a custom curve for one fan in one power profile. | Leave **Enabled** off. The firmware controls all three fans. The graph still shows the stored firmware curve while the box is off. |
| GPU Configuration | Change firmware GPU options. | Change these only when you mean to. Some changes need a reboot and can stay set outside Nix. |
| Battery Info | Check battery health, charge state, and power use. | The charge limit is set to 80% in [`hosts/boreas/asusd/asusd.ron`](hosts/boreas/asusd/asusd.ron). |
| App Settings | Control the window, tray, and notifications. | Leave **Start app on system startup** off. NixOS already starts it. |

### Fan curves

The **Enabled** box does not turn the physical fan on or off. It tells `asusd`
to replace the firmware's automatic curve with the curve shown in the graph.
Each fan and each power profile has its own box.

All boxes are off by design. This keeps the ASUS firmware in charge of the
CPU, GPU, and middle fans. If we choose custom curves later, change
[`hosts/boreas/asusd/fan_curves.ron`](hosts/boreas/asusd/fan_curves.ron) so the
setting survives a rebuild and reboot. Use **Factory Default (all fans)** to
load the laptop's factory curves for the selected power profile.

The upstream [asusctl 6.3.11 manual](https://github.com/OpenGamingCollective/asusctl/blob/6.3.11/MANUAL.md#fan-curves)
has the full fan-curve format. The
[6.3.11 fan-control code](https://github.com/OpenGamingCollective/asusctl/blob/6.3.11/asusd/src/ctrl_fancurves.rs)
shows that enabling a curve applies it immediately when its power profile is
active.

## TODOs

- [ ] Make hosts/boreas a bit more modular. Move out stuff like the nvidia configuration into a separate module to allow for better composition moving forward
- [x] Add shell aliases for the `nixos-rebuild` and `home-manager switch` flake commands
- [x] Break apart Gnome home-manager module into sub-modules
- [x] Break apart hyprland home-manager module into sub-modules
- [ ] Break apart user home-manager module into sub-modules
- [x] Delete old Hyprland QML and legacy desktop shell plumbing code
- [ ] Look into declaratively setting up a wallpaper (**Optional**)

## Troubleshooting

### Not booting up?

You probably need to update the `hosts/<hostname>/hardware-configuration.nix` file with what's in `/etc/nixos/hardware-configuration.nix`. Run

```shell
./scripts/regenerate-hardware-configuration.sh <hostname>
```

The bootloader is configured separately, in `hosts/<hostname>/default.nix`, and
the current `boreas` values are VM-only (`boot.loader.grub.device = "/dev/vda"`).
On real hardware this must be replaced before the first `nixos-rebuild`:

- UEFI machines (e.g. the Zephyrus): use `boot.loader.systemd-boot.enable = true`
  with `boot.loader.efi.canTouchEfiVariables = true`, and drop the GRUB block.
- BIOS machines: keep GRUB but point `boot.loader.grub.device` at the actual disk
  (e.g. `/dev/nvme0n1` / `/dev/sda`), not `/dev/vda`.
