{
  stdenv,
  lib,
  fetchFromGitHub,
  ...
}:

# Derivation for https://github.com/mngshm/rxfetch
stdenv.mkDerivation {
  pname = "rxfetch";
  version = "unstable-2025-06-25";

  src = fetchFromGitHub {
    owner = "mngshm";
    repo = "rxfetch";
    rev = "5eb3582d90a688c8330d1a72c6ac4c1b1ccd3872";
    sha256 = "sha256-S7OGGkeuARihhL/kUMuthFT58d8/fo/QcVKQKAQMs0Y=";
  };

  # Tells nix that no compilation or build step is necessary for realizing this derivation since there is already a compiled binary we can just `install`
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 rxfetch $out/bin/rxfetch

    runHook postInstall
  '';
}
