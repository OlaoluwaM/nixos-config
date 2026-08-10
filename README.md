# NixOS Setup

Based off the minimal startup config in [this repo](https://github.com/Misterio77/nix-starter-configs)

## Usage

Clone this repo in the `$HOME` directory.

Run any one of the following to apply our system configuration:

- `sudo nixos-rebuild switch --flake $HOME/nixos-config#hostname`
- `sudo nixos-rebuild switch --flake "$HOME/nixos-config#hostname"`
- `sudo nixos-rebuild switch --flake ~/nixos-config#hostname`
- `cd ~/nixos-config` then run `sudo nixos-rebuild switch --flake .#hostname`

After we must setup/initialize home-manager using the following command (the flake path can be specified in the same manner as above). We run this only once. Once this is done we should be able to just use `home-manager switch --flake ...` (<https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-prerequisites>)

This repo intentionally uses a stable base with selected unstable packages:

- `nixpkgs` points at `nixos-26.05`.
- `home-manager` points at `release-26.05` and follows stable `nixpkgs`.
- `nixpkgs-unstable` is imported separately and passed in as `unstable` for specific packages that benefit from newer versions.

That keeps the NixOS and Home Manager module systems aligned while still allowing newer user packages where needed. This is the safer default for a daily-driver machine and is friendlier while learning Nix than running the whole config on unstable.

If we want to move Home Manager to `master`, then we'd need to have Home Manager track nixpkgs-unstable. In `flake.nix`, change `home-manager.url` to `github:nix-community/home-manager/master` and strongly consider changing `home-manager.inputs.nixpkgs.follows` from `nixpkgs` to `nixpkgs-unstable`. For a fully unstable setup, also make the standalone Home Manager `pkgs` come from `nixpkgs-unstable`. Do not change `home.stateVersion` just because the branch changes; that value is a compatibility pin for migration defaults, not the active Home Manager version. In the command below, we'd also replace `release-26.05` with `master` too.

But the current setup is fine for now. It seems to be the ideal/standard setup. No need to switch it unless there is a compelling reason and if one does arise, it should be documented.

```bash
# Match the Home Manager branch pinned in flake.nix.
nix run github:nix-community/home-manager/release-26.05 -- switch -b backup --flake ~/nixos-config#olaolu@boreas
```

Finally, after the above command completes successfully we should be able to just run `home-manager` as a standalone tool like so to apply your home configuration.

```bash
home-manager switch --flake .#username@hostname
```

NOTE: All `nixos-rebuild` or `home-manager` commands must reference the flake (using `--flake`) to work as you'd expect.

### Apply order: system first, then home

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#boreas
home-manager switch --flake ~/nixos-config#olaolu@boreas
```

On a fresh install this order is mandatory: standalone Home Manager can only run once `nixos-rebuild` has produced what it needs (our user account, the nix daemon, `allowed-users`). Afterwards the two are independent — if only one layer changed, running just that layer's `switch` is fine — but for changes spanning both, keep system first: the home config usually assumes system plumbing (sessions, groups, dbus services) that should land before it. Cross-layer changes may also need a re-login for `hm-session-vars.sh` to take effect.

## Automatic Updates (Deprecated)

> [!note]
> We have disabled automatic updates because they seem like they'll be more trouble than they're worth, at least on NixOS. Updates will happen manually with a `nix flake update` followed by a `sudo nixos-rebuild switch --flake ...` then a `home-manager switch --flake ...`. Perhaps I ought to wrap all that up in a shell function or alias. In any case, no auto upgrades. Though, it might interest us to look into update the `flake.lock` using Github Actions in CI. Apparently people do that...

This repo uses two automatic upgrade timers with separate responsibilities:

- Home Manager chooses newer package versions by updating `flake.lock`, then updates the user profile.
- NixOS updates the operating system using whatever package versions has been pinned by `flake.lock`.

The split is intentional. `flake.lock` is this repo's package-version snapshot: it says exactly which versions this machine should use. Home Manager runs as the user, the normal owner of the file, so it is the safer place to edit it. NixOS auto-upgrade runs as `root`, the administrator account. If root edits files inside this user-owned repo, git may complain about ownership or it may lead to some unexpected outcome.

Either way, the rule for now is: Home Manager auto updates run first to update version snapshot (`flake.lock`) when needed. NixOS auto updates are scheduled to run after and only read from the version snapshot.

Again, if both timers run on the same day, schedule Home Manager first so the system update can use the latest version snapshot.

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
