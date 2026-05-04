# NOTE: This is just a simple example of how to make a flake out of a derivation/buildGoModule it is not being used
{
  description = "A CLI tool to view Hacker Laws in the terminal.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        version = "1.0.1";
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "hacker-laws-cli";
          version = version;
          src = pkgs.fetchFromGitHub {
            owner = "umutphp";
            repo = "hacker-laws-cli";
            rev = "v${version}";
            hash = "ferevewedrg"; # TODO: Fake hash, nix will give you the right one to replace this with
          };
          vendorHash = "fervdweqerv243f"; # TODO: Fake hash, nix will give you the right one to replace this with
        };
      }
    );
}
