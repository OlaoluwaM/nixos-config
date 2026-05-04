{
  stdenv,
  fetchFromGitHub,
  ...
}:

# For https://github.com/mngshm/rxfetch
stdenv.mkDerivation {
  pname = "rxfetch";
  version = "unstable-2025-06-25";

  src = fetchFromGitHub {
    owner = "mngshm";
    repo = "rxfetch";
    rev = "5eb3582d90a688c8330d1a72c6ac4c1b1ccd3872";
    sha256 = "freerwever"; # TODO: Fill this in when nix tells us what it should be
  };

  # Tells nix that there is no compile step since there is already a compiled binary so skip trying out the build phase
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 rxfetch $out/bin/rxfetch

    runHook postInstall
  '';
}
