{
  final,
  unstable,
  minimumVersion ? "6.3.11",
}:

if final.lib.versionAtLeast unstable.asusctl.version minimumVersion then
  unstable.asusctl
else
  unstable.asusctl.overrideAttrs (_: {
    version = minimumVersion;

    src = final.fetchFromGitHub {
      owner = "OpenGamingCollective";
      repo = "asusctl";
      tag = minimumVersion;
      hash = "sha256-g/AZuXbAMrq9mIUCpm2oNhFClNcP3OjqbrL3zr+lJS8=";
    };

    # The 6.3.11 archive does not include Cargo.lock. Nix needs that file before
    # it can download the Rust dependencies, so cargoHash alone cannot package
    # this release. Keep our generated lockfile here to make the build repeatable.
    # TODO: Check whether 6.3.12 ships Cargo.lock. If it does, remove this local
    # lockfile and use cargoHash again.
    cargoHash = null;
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = ./asusctl-6.3.11-Cargo.lock;
      outputHashes = {
        "slint-1.18.0" = "sha256-GH6cRi6D4FE7gfpi/Dx6DCsAb5HQeZb1Zy3dsIBhS7s=";
      };
    };

    # The 6.3.8 expression patches the vendored `sg` crate. That dependency was
    # removed before 6.3.11, so repeat the still-applicable patches without it.
    postPatch = ''
      files="
        asusd-user/src/config.rs
        asusd-user/src/daemon.rs
        asusd/src/aura_anime/config.rs
        rog-aura/src/aura_detection.rs
        rog-control-center/src/lib.rs
        rog-control-center/src/main.rs
        rog-control-center/src/tray.rs
      "
      for file in $files; do
        substituteInPlace $file --replace-fail /usr/share $out/share
      done

      substituteInPlace rog-control-center/src/main.rs \
        --replace-fail 'std::env::var("RUST_TRANSLATIONS").is_ok()' 'true'

      substituteInPlace data/asusd.service \
        --replace-fail /usr/bin/asusd $out/bin/asusd \
        --replace-fail /bin/sleep ${final.lib.getExe' final.coreutils "sleep"}

      substituteInPlace data/asus-shutdown.service \
        --replace-fail /usr/bin/asus-shutdown $out/bin/asus-shutdown

      substituteInPlace Makefile \
        --replace-fail /usr/bin/grep ${final.lib.getExe final.gnugrep}

      cp ${./asusctl-6.3.11-Cargo.lock} Cargo.lock
    '';
  })
