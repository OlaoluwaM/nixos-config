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
    # Keep Caffyne on its tested GTK/Python package set. Fabric currently fails
    # at import time against the PyGObject version in this flake's Nixpkgs.
    caffyne.url = "github:caffyne-org/caffyne-shell";
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-cli.url = "github:sadjow/codex-cli-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    catppuccin.url = "github:catppuccin/nix/release-26.05";
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
          desktopProfile = "gnome"; # Can be "hyprland" or "gnome"
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
        system = boreas.system; # NOTE: replace x86_64-linux with your architecture if necessary
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "electron-39.8.10" ];
        };
      };
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
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        # For a new profile/user, just add a new entry like "olaolu@boreas" but with the name set to olaolu@<new-hostname>. You may want to replace the system arch if necessary username@hostname
        "${boreas.username}@boreas" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.${boreas.system}; # NOTE: replace x86_64-linux with your architecture if necessary
          # All of these will be passed to every imported HM module
          extraSpecialArgs = {
            inherit inputs unstable;
            hostConfig = boreas;
          };
          # > Our main home-manager configuration file <
          # For a new user profile, you'd need a new entry and replace `./home/olaolu` with whatever the new profile user name is
          modules = [
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
        };
      };
    };
}
