{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

let
  version = "0.1.0";
in
rustPlatform.buildRustPackage {
  pname = "goldfish";
  inherit version;

  src = fetchFromGitHub {
    owner = "sameoldlab";
    repo = "goldfish";
    rev = "v${version}";
    hash = "sha256-+FlRwwtLFlzxcgtkdD47G/yrqYKgzo0pWKH1RIBli8A=";
  };

  cargoHash = "sha256-OJEw436p+P1dW1JSxX1EbyuDJBf4fMbHhpmavrbzTsw=";

  meta = {
    description = "IPC fuzzy file finder";
    homepage = "https://github.com/sameoldlab/goldfish";
    license = lib.licenses.mpl20;
    mainProgram = "gf";
  };
}
