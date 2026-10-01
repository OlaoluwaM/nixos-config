{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.obsStudio;

  # C23 strrchr preserves const from the filename passed to the shader loaders.
  obsNoisePackage = unstable.obs-studio-plugins.obs-noise.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./obs-noise-const-filenames.patch ];
  });
in
{
  options.local.obsStudio = {
    enable = lib.mkEnableOption "OBS Studio configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;

      package = unstable.obs-studio.override {
        cudaSupport = config.local.capabilities.graphics.cuda;
      };

      plugins = with unstable.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vkcapture
        obsNoisePackage
        obs-aitum-multistream
      ];
    };
  };
}
