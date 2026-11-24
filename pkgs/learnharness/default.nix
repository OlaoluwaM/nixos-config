{
  lib,
  appimageTools,
  fetchurl,
}:

let
  version = "0.7.0";
  pname = "learnharness";

  src = fetchurl {
    url = "https://github.com/amosblomqvist/learnharness/releases/download/v${version}/LearnHarness-${version}-x86_64.AppImage";
    hash = "sha256-dyteBNOAy+inKnXb/yaa62pH9NRFJxGx2oBZqHIGdhM=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/learnharness.desktop $out/share/applications/learnharness.desktop
    substituteInPlace $out/share/applications/learnharness.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/learnharness.png \
      $out/share/icons/hicolor/512x512/apps/learnharness.png
  '';

  meta = {
    description = "Agent harness for learning: adaptive teaching, practice, and a persistent knowledge graph";
    homepage = "https://github.com/amosblomqvist/learnharness";
    downloadPage = "https://github.com/amosblomqvist/learnharness/releases";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "learnharness";
    platforms = [ "x86_64-linux" ];
  };
}
