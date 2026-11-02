{
  config,
  lib,
  pkgs,
  inputs,
  unstable,
  ...
}:

let
  cfg = config.local.omp;

  piAutomode = pkgs.callPackage ../../../pkgs/pi-automode {
    src = inputs.pi-automode;
    inherit (unstable) bun;
  };

  automodeConfig = {
    autoMode = {
      classifierModel = "openai-codex/gpt-6.1-terra";
      classifierReasoningLevel = "low";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    programs.omp.settings = {
      extensions = [ "${piAutomode}" ];
      tools.approvalMode = "yolo";
    };

    home.file.".pi/agent/extensions/pi-automode/config.json".text = builtins.toJSON automodeConfig;
  };
}
