{
  lib,
  python3Packages,
  fetchFromGitHub,
  wrapGAppsHook4,
  gobject-introspection,
  gtk4,
  networkmanager,
  ...
}:

python3Packages.buildPythonApplication {
  pname = "airctl";
  version = "0.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "pshycodr";
    repo = "airctl";
    rev = "v0.4.0";
    hash = "sha256-DwVMG4U7GKgSuJkC+5bxpUZ/c2n4TN2z9BZ5q37OWKA=";
  };

  nativeBuildInputs = [
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    gtk4
  ];

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    nmcli
    pygobject3
    rich
  ];

  pythonRelaxDeps = [
    "nmcli"
    "rich"
  ];

  pythonRemoveDeps = [
    "nuitka"
  ];

  postInstall = ''
    install -Dm644 airctl.desktop $out/share/applications/airctl.desktop
    install -Dm644 assets/airctl.png $out/share/icons/hicolor/256x256/apps/airctl.png
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : "${lib.makeBinPath [ networkmanager ]}"
    )
  '';

  dontWrapGApps = false;

  makeWrapperArgs = [
    "\${gappsWrapperArgs[@]}"
  ];

  pythonImportsCheck = [
    "airctl"
  ];

  meta = {
    description = "WiFi network manager GUI for Linux";
    homepage = "https://github.com/pshycodr/airctl";
    license = lib.licenses.gpl3Only;
    mainProgram = "airctl";
  };
}
