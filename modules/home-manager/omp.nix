{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.omp;
  home = config.home.homeDirectory;
  yaml = pkgs.formats.yaml { };

  models = {
    providers.zai-api = {
      baseUrl = "https://api.z.ai/api/paas/v4";
      api = "openai-completions";
      apiKey = "GLM_API_KEY";
      models = [
        {
          id = "glm-5.3-flash";
          name = "GLM-5.3-Flash (API)";
          reasoning = true;
          input = [
            "text"
            "image"
          ];
          contextWindow = 1000000;
          maxTokens = 131072;
          cost = {
            input = 0.15;
            output = 0.5;
            cacheRead = 0.03;
            cacheWrite = 0;
          };
        }
      ];
    };
  };
in
{
  # https://github.com/can1357/oh-my-pi
  options.local.omp = {
    enable = lib.mkEnableOption "oh-my-pi configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.omp = {
      enable = true;
      settings = {
        startup = {
          quiet = true;
          checkUpdate = false;
        };

        modelRoles = {
          default = "openai-codex/gpt-6-astra:high";
          plan = "openai-codex/gpt-6-astra:xhigh";
          slow = "openai-codex/gpt-6-astra:xhigh";
          task = "openai-codex/gpt-6.1-sol:medium";
          commit = "openai-codex/gpt-6.1-sol:low";
          vision = "openai-codex/gpt-6.1-sol";
          advisor = "openai-codex/gpt-6.1-sol:medium";
          smol = "zai-api/glm-5.3-flash:low";
          review = "moonshot/kimi-k3.1-pro:high";
        };

        enabledModels = [
          "openai-codex/gpt-6-astra"
          "openai-codex/gpt-6.1-sol"
          "moonshot/kimi-k3.1-pro"
          "zai-api/glm-5.3-flash"
        ];

        task = {
          maxConcurrency = 8;
          agentModelOverrides.reviewer = "@review";
        };

        tools.approvalMode = "write";
        providers.openai-codex.daybreak = false;
        advisor.enabled = true;
        memory.backend = "local";
        session.warnCost = 25;
        skills.customDirectories = [ "${home}/.claude/skills" ];
      };
    };

    home.file = {
      ".omp/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/Desktop/agent-context/Context/Global Preferences.md";
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" models;
      ".omp/agent/tools/ask-claude.ts".source = ./omp/ask-claude.ts;
      ".omp/agent/RULES.md".text = ''
        Use the ask_claude tool for every code review, second opinion, and adversarial review, including reviews you would otherwise hand to the reviewer subagent. Use sonnet for routine and repeated review passes, and opus or fable for a first-pass adversarial or final review. Fall back to the reviewer subagent only when ask_claude fails, and say that you did.
      '';
    };
  };
}
