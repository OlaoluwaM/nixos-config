{
  lib,
  stdenvNoCC,
  bun,
  cacert,
  src,
}:

let
  pname = "omp-claude-bridge";
  version = src.shortRev or "unknown";

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
    outputHash = "sha256-0zr05A+Jy6gunJsSGEUVZsFKGjt70Ft6SZT2qSM4Ixc=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R package.json src LICENSE NOTICE "$out/"
    cp -R ${nodeModules} "$out/node_modules"
    runHook postInstall
  '';

  meta = {
    description = "Oh My Pi extension that runs Claude Code models through the Claude Agent SDK";
    homepage = "https://github.com/OlaoluwaM/omp-claude-bridge";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
