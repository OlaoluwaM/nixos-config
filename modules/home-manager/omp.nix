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
  home = config.home.homeDirectory;
  yaml = pkgs.formats.yaml { };

  ompClaudeBridge = pkgs.callPackage ../../pkgs/omp-claude-bridge {
    src = inputs.omp-claude-bridge;
    inherit (unstable) bun;
  };

  claudeBridgeConfig = {
    provider = {
      plan = "max";
      pathToClaudeCodeExecutable = "${pkgs.claude-code}/bin/claude";
      outputStyle = "omp-bridge";
    };
  };

  models = {
    providers.anthropic.apiKey = "!cat ${home}/.omp/agent/anthropic-api-key";
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
          smol = "anthropic/claude-haiku-5-5:low";
          review = "anthropic/claude-sonnet-5-5:high";
        };

        retry.fallbackChains = {
          smol = [ "zai-api/glm-5.3-flash:low" ];
          review = [ "moonshot/kimi-k3.1-pro:high" ];
        };

        enabledModels = [
          "openai-codex/gpt-6-astra"
          "openai-codex/gpt-6.1-sol"
          "anthropic/claude-haiku-5-5"
          "anthropic/claude-sonnet-5-5"
          "claude-bridge/claude-opus-5-5"
          "claude-bridge/claude-sonnet-5-5"
          "claude-bridge/claude-fable-5-1"
          "claude-bridge/claude-haiku-5-5"
          "moonshot/kimi-k3.1-pro"
          "zai-api/glm-5.3-flash"
        ];

        extensions = [ "${ompClaudeBridge}" ];

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
      ".omp/agent/claude-bridge.json".text = builtins.toJSON claudeBridgeConfig;
      ".omp/agent/tools/ask-claude.ts".source = ./omp/ask-claude.ts;
      ".omp/agent/RULES.md".text = ''
        Use the ask_claude tool for every code review, second opinion, and adversarial review, including reviews you would otherwise hand to the reviewer subagent. Use sonnet for routine and repeated review passes, and opus or fable for a first-pass adversarial or final review. Fall back to the reviewer subagent only when ask_claude fails, and say that you did.
      '';
      ".claude/output-styles/omp-bridge.md".text = ''
        ---
        name: omp-bridge
        description: Claude Code as the model behind oh-my-pi (omp)
        keep-coding-instructions: false
        ---

        In this session Claude Code is the model provider for oh-my-pi (omp), a separate coding-agent harness. omp owns the conversation, the tools, approvals, compaction and subagents.

        - Claude Code's built-in tools are not loaded. The tools you can call are omp's, served over MCP as `mcp__custom-tools__<name>`. Use only those, with the schemas they provide.
        - The instructions appended after this section come from omp and from the user's own context files. Follow them for workflow, tool use, delegation and response style. Where they name a tool such as `read`, `edit`, `bash` or an `xd://` device, they mean the omp tool of that name.
        - Claude Code's safety and security guidance above still applies.
      '';
    };
  };
}
