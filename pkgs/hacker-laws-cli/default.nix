{
  buildGoModule,
  pkgs,
  ...
}:

# For https://github.com/umutphp/hacker-laws-cli
let
  version = "1.0.1";
in
buildGoModule {
  pname = "hacker-laws-cli";
  version = version;
  src = pkgs.fetchFromGitHub {
    owner = "umutphp";
    repo = "hacker-laws-cli";
    rev = "v${version}";
    hash = "ferevewedrg"; # TODO: Fake hash, nix will give you the right one to replace this with
  };
  vendorHash = "fervdweqerv243f"; # TODO: Fake hash, nix will give you the right one to replace this with
}
