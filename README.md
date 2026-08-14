# NixOS Setup

Based off the minimal startup config in [this repo](https://github.com/Misterio77/nix-starter-configs)

## Usage

> [!note]
> All `nixos-rebuild` or `home-manager` commands must reference the flake (using `--flake`) to work as you'd expect.

Clone this repo in the `$HOME` directory.

**Then for the first time only, following a fresh installation of NixOS, run the script `scripts/fresh-install-first-rebuild-switch.sh`. It will do two things:**

1. Refresh the `hardware-configuration.nix` module in `hosts/$HOST` so it aligns with what NixOS expects
2. Runs a `nixos-rebuild switch --flake ...`.

After that, run any one of the following to apply the system configuration from this repo moving forward:

- `sudo nixos-rebuild switch --flake $HOME/nixos-config#hostname`
- `sudo nixos-rebuild switch --flake "$HOME/nixos-config#hostname"`
- `sudo nixos-rebuild switch --flake ~/nixos-config#hostname`
- `cd ~/nixos-config` then run `sudo nixos-rebuild switch --flake .#hostname`

Make sure, regardless of the command you use, the nixos switch passes successfully.

If the above command was successful, we must then setup/initialize home-manager using the following command (the flake path can be specified in the same manner as with the `nixos-rebuild`). We run this only once. 

```bash
# Version used here must match the version of the Home Manager branch pinned in flake.nix.
nix run github:nix-community/home-manager/release-26.05 -- switch -b backup --flake ~/nixos-config#$USER@$HOST
```

Once this is done we should be able to just use home-manager directly (<https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-prerequisites>)

```bash
home-manager switch --flake .#username@hostname
```

This repo intentionally uses a stable base with selected unstable packages:

- `nixpkgs` points at `nixos-26.05`.
- `home-manager` points at `release-26.05` and follows stable `nixpkgs`.
- `nixpkgs-unstable` is imported separately and passed in as `unstable` for specific packages that benefit from newer versions.

That keeps the NixOS and Home Manager module systems aligned while still allowing newer user packages where needed. This is the safer default for a daily-driver machine and is friendlier while learning Nix than running the whole config on unstable.

If we wanted to move Home Manager to `master`, we'd need to have Home Manager track nixpkgs-unstable. In `flake.nix`, this means changing `home-manager.url` to `github:nix-community/home-manager/master` and changing `home-manager.inputs.nixpkgs.follows` from `nixpkgs` to `nixpkgs-unstable`. For a fully unstable setup, we'd also make the standalone Home Manager `pkgs` come from `nixpkgs-unstable`.


### Apply order: system first, then home

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#$HOST
home-manager switch --flake ~/nixos-config#$USER@$HOST
```

On a fresh install this order is mandatory: standalone Home Manager can only run once `nixos-rebuild` has produced what it needs (our user account, the nix daemon, `allowed-users`). Afterwards the two are independent. If only one layer changed, running just that layer's `switch` is fine, but for changes spanning both, keep system first: the home config usually assumes system plumbing (sessions, groups, dbus services) that should land before it. Cross-layer changes may also need a re-login for `hm-session-vars.sh` to take effect.

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
- [ ] Break apart hyprland home-manager module into sub-modules
- [ ] Break apart user home-manager module into sub-modules
- [ ] Delete old Hyprland QML and Caffyne OS plumbing code
- [ ] Look into declaratively setting up a wallpaper (**Optional**)

## Troubleshooting

### Not booting up?

You probably need to update the `hosts/<hostname>/hardware-configuration.nix` file with what's in `/etc/nixos/hardware-configuration.nix`. Run

```shell
cp /etc/nixos/hardware-configuration.nix ~/nixos-config/hosts/<hostname>/
```

The bootloader is configured separately, in `hosts/<hostname>/default.nix`, and
the current `boreas` values are VM-only (`boot.loader.grub.device = "/dev/vda"`).
On real hardware this must be replaced before the first `nixos-rebuild`:

- UEFI machines (e.g. the Zephyrus): use `boot.loader.systemd-boot.enable = true`
  with `boot.loader.efi.canTouchEfiVariables = true`, and drop the GRUB block.
- BIOS machines: keep GRUB but point `boot.loader.grub.device` at the actual disk
  (e.g. `/dev/nvme0n1` / `/dev/sda`), not `/dev/vda`.

