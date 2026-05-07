# NixOS Setup

Based off the minimal startup config in [this repo](https://github.com/Misterio77/nix-starter-configs)

## Automatic Updates

This repo uses two automatic upgrade timers with separate responsibilities:

- Home Manager chooses newer package versions by updating `flake.lock`, then updates the user profile.
- NixOS updates the operating system using whatever package versions has been pinned by `flake.lock`.

The split is intentional. `flake.lock` is this repo's package-version snapshot: it says exactly which versions this machine should use. Home Manager runs as the user, the normal owner of the file, so it is the safer place to edit it. NixOS auto-upgrade runs as `root`, the administrator account. If root edits files inside this user-owned repo, git may complain about ownership or it may lead to some unexpected outcome.

Either way, the rule for now is: Home Manager auto updates run first to update version snapshot (`flake.lock`) when needed. NixOS auto updates are scheduled to run after and only read from the version snapshot.

Again, if both timers run on the same day, schedule Home Manager first so the system update can use the latest version snapshot.
