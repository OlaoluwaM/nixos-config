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

  automodeSettings = {
    classifierModel = "openai-codex/gpt-6.1-sol";
    classifierReasoningLevel = "low";
    classifierTimeoutMs = 14000;
    allowInsideWorkingDirectory = true;
    log = {
      enabled = true;
      classifierIo = false;
    };
  };

  automodeConfig =
    pkgs.runCommand "pi-automode-config.json"
      {
        nativeBuildInputs = [
          pkgs.claude-code
          pkgs.jq
        ];
        settings = builtins.toJSON automodeSettings;
        passAsFile = [ "settings" ];
      }
      ''
        export HOME="$TMPDIR"
        claude auto-mode defaults > rules.json
        jq --slurpfile settings "$settingsPath" \
          '{ autoMode: ($settings[0] + { environment, allow, soft_deny, hard_deny }) }' \
          rules.json > "$out"
      '';
in
{
  config = lib.mkIf cfg.enable {
    programs.omp.settings = {
      extensions = [ "${piAutomode}" ];
      tools.approvalMode = "yolo";
    };

    home.file.".pi/agent/extensions/pi-automode/config.json".source = automodeConfig;
  };
}
