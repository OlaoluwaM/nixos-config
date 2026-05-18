{
  buildGoModule,
  pkgs,
  lib,
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
    hash = "sha256-WakuKWsioco6w5T5mpfWba4prCQShPkTgO0vCLUWG5g=";
  };
  vendorHash = "sha256-XpJ0QleQcq/+dho2+tMdyCGlKkH2eO7V3qQyQxdPCsg=";
}
