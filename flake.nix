{
  description = "My nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    claude-code.url = "github:sadjow/claude-code-nix";
    codex-cli.url = "github:sadjow/codex-cli-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
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
      ...
    }@inputs:

    let
      hosts = {
        # Having user data associated with a host does not lend itself to multi-user setups. Fortunately, boreas is a personal computer so coupling it with the single user I'll be using is fine. For a multi-user, host, however, we'd want to avoid this coupling. We could also consider this coupled user to be the "primary" user or something like that

        # The user details defined here will be used (1) to parameterize the boreas nixos config and (2) to select the appropriate home-manager user profile
        boreas = rec {
          hostName = "boreas";
          system = "x86_64-linux";
          username = "olaolu";
          userFullName = "Olaoluwa Mustapha";
          nixosConfigPath = "/home/${username}/nixos-config";
          # Change this to "hyprland" to swap from the full GNOME DE to the Hyprland WM.
          desktopProfile = "gnome";
          enableAsusRogKeybindings = true;
          dotfilesRelativePath = "dotfiles/boreas/nixos";
          devDirname = "dev";
          gpu = "nvidia";
        };
      };

      boreas = hosts.boreas;
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        # For a new system, just add a new entry like boreas. Although you may want to replace the system arch if necessary
        ${boreas.hostName} = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            hostConfig = boreas;
            unstable = import nixpkgs-unstable {
              system = boreas.system; # NOTE: replace x86_64-linux with your architecture if necessary
              config = {
                allowUnfree = true;
              };
            };
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
        "${boreas.username}@${boreas.hostName}" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.${boreas.system}; # NOTE: replace x86_64-linux with your architecture if necessary
          # All of these will be passed to every imported HM module
          extraSpecialArgs = {
            inherit inputs;
            hostConfig = boreas;
            unstable = import nixpkgs-unstable {
              system = boreas.system; # NOTE: replace x86_64-linux with your architecture if necessary
              config = {
                allowUnfree = true;
              };
            };
          };
          # > Our main home-manager configuration file <
          # For a new user profile, you'd need a new entry and replace `./home/olaolu` with whatever the new profile user name is
          modules = [
            nix-flatpak.homeManagerModules.nix-flatpak
            # We're getting claude-code from this repo https://github.com/sadjow/claude-code-nix to always have the most up to date version
            # The same guy also has a repo for codex https://github.com/sadjow/codex-cli-nix
            {
              nixpkgs.overlays = [
                claude-code.overlays.default
                codex-cli.overlays.default
              ];
            }
            ./home/${boreas.username}
          ];
        };
      };
    };
}
