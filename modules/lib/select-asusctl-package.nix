{
  final,
  unstable,
  minimumVersion ? "6.3.11",
}:

if final.lib.versionAtLeast unstable.asusctl.version minimumVersion then
  unstable.asusctl
else
  unstable.asusctl.overrideAttrs (_old: {
    version = minimumVersion;

    src = final.fetchFromGitHub {
      owner = "OpenGamingCollective";
      repo = "asusctl";
      tag = minimumVersion;
      hash = final.lib.fakeHash;
    };

    cargoHash = final.lib.fakeHash;
  })
