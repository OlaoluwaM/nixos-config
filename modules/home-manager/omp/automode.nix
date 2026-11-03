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
    fastClassifierModel = "typesafe/jev-1.14.0";
    injectionProbeModel = "typesafe/jev-1.14.0";
    allowInsideWorkingDirectory = true;
    log = {
      enabled = true;
      classifierIo = false;
    };
  };

  # Appended to the default allow rules from `claude auto-mode defaults`.
  extraAllowRules = [
    "Note-Review Bookkeeping: When the user has asked in this session for a note review (review-note or review-note-deep), these steps are user-authorized and are not scope escalation, Irreversible Local Destruction, or Unrequested Commit in a Connected App: (1) writing or replacing entries in ~/Desktop/agent-context/Review Cache/_anchors-p1-working-set.md, _anchors-p2-working-set.md, and files under _anchors-archive/; (2) writing files inside ~/Desktop/agent-context/Review Cache/<review_id>/ and deleting that directory's .review-progress.md; (3) running `nlm notebook create` titled after the reviewed note and `nlm source add --url` with URLs listed in that cache's sources.md. Does NOT cover other files under ~/Desktop/agent-context, deleting cache directories, other nlm commands (delete, share, studio/audio generation), or sending note text to NotebookLM."
  ];

  automodeConfig =
    pkgs.runCommand "pi-automode-config.json"
      {
        nativeBuildInputs = [
          pkgs.claude-code
          pkgs.jq
        ];
        settings = builtins.toJSON automodeSettings;
        extraAllow = builtins.toJSON extraAllowRules;
        passAsFile = [
          "settings"
          "extraAllow"
        ];
      }
      ''
        export HOME="$TMPDIR"
        claude auto-mode defaults > rules.json
        jq --slurpfile settings "$settingsPath" --slurpfile extraAllow "$extraAllowPath" \
          '{ autoMode: ($settings[0] + { environment, allow: (.allow + $extraAllow[0]), soft_deny, hard_deny }) }' \
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
