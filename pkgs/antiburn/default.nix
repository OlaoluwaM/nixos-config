{
  lib,
  appimageTools,
  fetchurl,
}:

let
  version = "0.9.0";
  pname = "antiburn";

  src = fetchurl {
    url = "https://github.com/antiburn/antiburn/releases/download/antiburn-v${version}/antiburn_${version}_amd64.AppImage";
    hash = "sha256:4b772ae214391c8499c6605b55fb055b044175221863bbb60bb3f7a411f192f7";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/antiburn.desktop $out/share/applications/antiburn.desktop

    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/antiburn.png \
      $out/share/icons/hicolor/512x512/apps/antiburn.png
  '';

  meta = {
    description = "Fast, free local checks to reduce your token burn. Helps you avoid limits by checking for: sessions too deep, models too powerful, caching broken, unused tools/MCPs/skills, and many more.";
    homepage = "https://github.com/antiburn/antiburn";
    downloadPage = "https://github.com/antiburn/antiburn/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "antiburn";
    platforms = [ "x86_64-linux" ];
  };
}
