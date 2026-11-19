{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.obsStudio;
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
        obs-noise
        obs-aitum-multistream
      ];
    };
  };
}
