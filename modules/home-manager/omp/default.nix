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

  ompClaudeBridge = pkgs.callPackage ../../../pkgs/omp-claude-bridge {
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
  imports = [
    ./automode.nix
    ./prompts.nix
    ./theme.nix
  ];

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

        setupVersion = 2;
        symbolPreset = "unicode";
        composer.shape = "box";

        modelRoles = {
          default = "claude-bridge/claude-opus-5-5:high";
          plan = "claude-bridge/claude-opus-5-5:xhigh";
          slow = "claude-bridge/claude-fable-5-1:high";
          task = "openai-codex/gpt-6.1-sol:medium";
          commit = "openai-codex/gpt-6.1-sol:low";
          vision = "openai-codex/gpt-6.1-sol";
          advisor = "openai-codex/gpt-6.1-sol:medium";
          smol = "openai-codex/gpt-6.1-terra:low,openai-codex/gpt-6-luna:low";
          tiny = "claude-bridge/claude-haiku-5-5:low";
          memory = "@smol";
          review = "openai-codex/gpt-6-astra:high";
        };

        retry = {
          fallbackOn = "usage-limit";
          fallbackChains = {
            default = [
              "openai-codex/gpt-6-astra:high"
              "openai-codex/gpt-6.1-sol:high"
              "moonshot/kimi-k3.1-pro:high"
            ];
            plan = [
              "openai-codex/gpt-6-astra:xhigh"
              "moonshot/kimi-k3.1-pro:high"
            ];
            slow = [
              "claude-bridge/claude-opus-5-5:xhigh"
              "openai-codex/gpt-6-astra:xhigh"
            ];
            smol = [ "zai-api/glm-5.3-flash:low" ];
            review = [
              "openai-codex/gpt-6.1-sol:high"
              "moonshot/kimi-k3.1-pro:high"
            ];
          };
        };

        enabledModels = [
          "openai-codex/gpt-6-astra"
          "openai-codex/gpt-6.1-sol"
          "openai-codex/gpt-6.1-terra"
          "openai-codex/gpt-6-luna"
          "claude-bridge/claude-opus-5-5"
          "claude-bridge/claude-sonnet-5-5"
          "claude-bridge/claude-fable-5-1"
          "claude-bridge/claude-haiku-5-5"
          "moonshot/kimi-k3.1-pro"
          "zai-api/glm-5.3-flash"
        ];

        disabledProviders = [ "anthropic" ];
        extensions = [ "${ompClaudeBridge}" ];

        task = {
          maxConcurrency = 8;
          agentModelOverrides.reviewer = "@review";
        };

        tools = {
          approval = {
            task = "allow";
            eval = "prompt";
          };
        };

        bash.patterns = [
          {
            match = "nixos-rebuild*";
            approval = "deny";
          }
          {
            match = "home-manager switch*";
            approval = "deny";
          }
          {
            match = "sudo *";
            approval = "deny";
          }
          {
            match = "git commit*";
            approval = "prompt";
          }
          {
            match = "git push*";
            approval = "prompt";
          }
          {
            match = "systemctl * restart *";
            approval = "prompt";
          }
          {
            match = "systemctl * stop *";
            approval = "prompt";
          }
          {
            match = "systemctl restart *";
            approval = "prompt";
          }
          {
            match = "systemctl stop *";
            approval = "prompt";
          }
        ];

        providers.openai-codex.daybreak = false;
        advisor = {
          enabled = true;
          continueSeverity = "blocker";
        };
        memory.backend = "mnemopi";
        mnemopi.scoping = "per-project-tagged";
        dev.autoqa = false;
        session.warnCost = 25;
        skills.customDirectories = [ "${home}/.claude/skills" ];
      };
    };

    home.file = {
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" models;
      ".omp/agent/claude-bridge.json".text = builtins.toJSON claudeBridgeConfig;
    };
  };
}
