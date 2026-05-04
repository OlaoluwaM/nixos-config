{
  description = "My nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

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
      home-manager,
      ...
    }@inputs:
    let
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        # For a new system, just add a new entry like boreas. Although you may want to replace the system arch if necessary
        boreas = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            unstable = import nixpkgs-unstable {
              system = "x86_64-linux"; # NOTE: replace x86_64-linux with your architecture if necessary
              config = {
                allowUnfree = true;
              };
            };
          };
          # > Our main nixos configuration file <
          # For another system config, you'd want to replace this too, to match the new system name
          modules = [ ./hosts/boreas ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        # For a new profile/user, just add a new entry like "olaolu@boreas" but with the name set to olaolu@<new-hostname>. You may want to replace the system arch if necessary username@hostname
        "olaolu@boreas" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # NOTE: replace x86_64-linux with your architecture if necessary
          extraSpecialArgs = {
            inherit inputs;
            unstable = import nixpkgs-unstable {
              system = "x86_64-linux"; # NOTE: replace x86_64-linux with your architecture if necessary
              config = {
                allowUnfree = true;
              };
            };
          };
          # > Our main home-manager configuration file <
          # For a new user profile, you'd need a new entry and replace `./home/olaolu` with whatever the new profile user name is
          modules = [
            inputs.nix-flatpak.homeManagerModules.nix-flatpak
            ./home/olaolu
          ];
        };
      };
    };
}
