{
  description = "My nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Other stuff
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-cli.url = "github:sadjow/codex-cli-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    catppuccin.url = "github:catppuccin/nix/release-26.05";
    # Vicinae from its own flake: nixpkgs lags upstream badly (0.23.x vs
    # 0.26.x), and upstream ships a cachix cache for exactly this input (see
    # nix.settings on boreas). Deliberately NOT following our nixpkgs — the
    # vicinae docs warn that a follows here defeats their cache. Update with
    # `nix flake update vicinae`.
    vicinae.url = "github:vicinaehq/vicinae";
    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # My fork of s3rven/silere-shell, the Quickshell/QML bar for the Hyprland
    # profile. Fork-side NixOS-compat commits land on custom-branch. Upstream
    # ships no flake and its packaging/ directory is AUR-only, so this is
    # pulled in as a plain source tree and packaged by
    # modules/home-manager/hyprland/silere.nix instead.
    silere-shell.url = "github:OlaoluwaM/silere-shell/custom-branch";
    silere-shell.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      claude-code,
      codex-cli,
      nixos-hardware,
      home-manager,
      nix-flatpak,
      catppuccin,
      ...
    }@inputs:

    let
      hosts = {
        # Having user data associated with a host does not lend well to multi-user setups. However, because boreas is a personal computer, coupling it with the single user I'll be using on it is fine. For a multi-user, host, though, we'd want to avoid this coupling. We could also consider this coupled user to be the "primary" user for boreas or something like that

        # The user details defined here will be used (1) to parameterize the boreas nixos config and (2) to select the appropriate home-manager user profile for boreas

        # With this approach as well, we don't need to add extra profile entries under homeManagerConfiguration to switch boreas to a different profile. Changing the user data associated with the boreas attribute set will do that automatically, so long as there is a `home/<username>/default.nix` file for the profile.
        boreas = rec {
          system = "x86_64-linux";
          username = "olaolu";
          userFullName = "Olaoluwa Mustapha";
          nixosConfigPath = "/home/${username}/nixos-config";
          desktopProfile = "hyprland"; # Can be "hyprland" or "gnome"
          dotfilesRelativePath = "dotfiles/boreas/nixos";
          devDirname = "dev";
        };
      };

      boreas = hosts.boreas;

      # Single unstable pkgs instance shared by the NixOS and Home Manager
      # entrypoints. electron-39 is marked insecure upstream but is pulled in
      # transitively by unstable.bitwarden-desktop; permit it here so the config
      # evaluates without --impure / NIXPKGS_ALLOW_INSECURE.
      unstable = import nixpkgs-unstable {
        system = boreas.system; # replace x86_64-linux with your architecture if necessary
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "electron-39.8.10" ];
        };
      };

      # All of these will be passed to every imported HM module
      homeSpecialArgs = {
        inherit inputs unstable;
        hostConfig = boreas;
      };

      # > Our main home-manager configuration modules <
      # Keeping these in one place lets both the NixOS-integrated and standalone
      # Home Manager entrypoints use the exact same configuration.
      homeModules = [
        ./home/${boreas.username}
        nix-flatpak.homeManagerModules.nix-flatpak
        {
          local.capabilities.graphics.cuda = true;
          local.capabilities.input.asusRogKeys = true;
        }
        # We're getting claude-code from this repo https://github.com/sadjow/claude-code-nix to always have the most up to date version
        # The same guy also has a repo for codex https://github.com/sadjow/codex-cli-nix
        {
          nixpkgs.overlays = [
            claude-code.overlays.default
            codex-cli.overlays.default
          ];
        }
        catppuccin.homeModules.catppuccin
      ];
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        # For a new system, just add a new entry like boreas. Although you may want to replace the system arch if necessary
        boreas = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs unstable;
            hostConfig = boreas;
          };

          # > Our main nixos configuration file <
          # For another system config, you'd want to replace this too, to match the new system name
          modules = [
            nixos-hardware.nixosModules.asus-zephyrus-gu603h
            ./hosts/boreas

            # Integrate Home Manager into the NixOS configuration so a normal
            # nixos-rebuild also activates the user's Home Manager configuration.
            home-manager.nixosModules.home-manager

            {
              # The NixOS Home Manager submodule intentionally does not install
              # the standalone CLI through programs.home-manager.enable. Add the
              # CLI from the same pinned flake input to this user's NixOS profile.
              users.users.${boreas.username}.packages = [
                home-manager.packages.${boreas.system}.default
              ];

              home-manager = {
                # Install Home Manager packages into the user's profile.
                useUserPackages = true;

                # We intentionally don't use useGlobalPkgs because the Home
                # Manager config has its own nixpkgs configuration and overlays.
                extraSpecialArgs = homeSpecialArgs;

                # Equivalent to '-b backup' when doing a standalone home-manager switch
                # but in this case the suffix will be 'nixos-hm-backup' instead of just 'backup'
                backupFileExtension = "nixos-hm-backup";
                # If a backup already exists `nixos-rebuild switch` will still fail. This option controls
                # whether nixos is allowed to overwrite the backups. Leave it as false for now
                overwriteBackup = false;

                users.${boreas.username} = {
                  imports = homeModules;
                };
              };
            }
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        # For a new profile/user, just add a new entry like "olaolu@boreas" but with the name set to olaolu@<new-hostname>. You may want to replace the system arch if necessary username@hostname
        "${boreas.username}@boreas" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.${boreas.system}; # replace x86_64-linux with your architecture if necessary

          # All of these will be passed to every imported HM module
          extraSpecialArgs = homeSpecialArgs;

          # > Our main home-manager configuration file <
          # For a new user profile, you'd need a new entry and replace `./home/olaolu` with whatever the new profile user name is
          modules = homeModules;
        };
      };
    };
}
