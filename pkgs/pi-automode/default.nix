{
  lib,
  stdenvNoCC,
  bun,
  cacert,
  src,
}:

let
  pname = "pi-automode";
  version = (lib.importJSON "${src}/package.json").version;

  nodeModules = stdenvNoCC.mkDerivation {
    pname = "${pname}-node-modules";
    inherit version src;

    nativeBuildInputs = [ bun ];
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      bun install --frozen-lockfile --omit=dev --omit=peer --omit=optional --ignore-scripts --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -R node_modules "$out"
      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-/spWqkTquIr+Z9npvJqNiT1CHX4SJwg+iJ2OagjnQ2c=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R package.json extensions skills LICENSE.md "$out/"
    cp -R ${nodeModules} "$out/node_modules"
    runHook postInstall
  '';

  meta = {
    description = "Claude Code-style auto mode for Pi and Oh My Pi: a classifier model screens tool calls before they run";
    homepage = "https://github.com/czottmann/pi-automode";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
