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

```bash
nix run github:nix-community/home-manager/master -- switch -b backup --flake ~/nixos-config#olaolu@boreas

# OR

nix run home-manager/master -- switch -b backup --flake ~/nixos-config#olaolu@boreas
```

Finally, after the above command completes successfully we should be able to just run `home-manager` as a standalone tool like so to apply your home configuration.

```bash
home-manager switch --flake .#username@hostname
```

NOTE: All `nixos-rebuild` or `home-manager` commands must reference the flake (using `--flake`) to work as you'd expect.

## Automatic Updates

This repo uses two automatic upgrade timers with separate responsibilities:

- Home Manager chooses newer package versions by updating `flake.lock`, then updates the user profile.
- NixOS updates the operating system using whatever package versions has been pinned by `flake.lock`.

The split is intentional. `flake.lock` is this repo's package-version snapshot: it says exactly which versions this machine should use. Home Manager runs as the user, the normal owner of the file, so it is the safer place to edit it. NixOS auto-upgrade runs as `root`, the administrator account. If root edits files inside this user-owned repo, git may complain about ownership or it may lead to some unexpected outcome.

Either way, the rule for now is: Home Manager auto updates run first to update version snapshot (`flake.lock`) when needed. NixOS auto updates are scheduled to run after and only read from the version snapshot.

Again, if both timers run on the same day, schedule Home Manager first so the system update can use the latest version snapshot.
