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

  catppuccinTheme =
    let
      upstream = (lib.importJSON "${inputs.omp}/packages/tui/src/theme/defaults.json").dark-catppuccin;
      accentTokens = [
        "accent"
        "mdHeading"
        "mdListBullet"
        "statusLineSubagents"
      ];
    in
    upstream
    // {
      name = "catppuccin-mocha";
      colors = upstream.colors // lib.genAttrs accentTokens (_: config.catppuccin.accent);
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
        theme.dark = if config.local.catppuccin.enable then catppuccinTheme.name else "titanium";

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
          approvalMode = "write";
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
      ".omp/agent/AGENTS.md".text = ''
        @~/.omp/agent/context/global-preferences.md

        @~/.omp/agent/context/output-style.md
      '';
      ".omp/agent/context/global-preferences.md".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/Desktop/agent-context/Context/Global Preferences.md";
      ".omp/agent/context/output-style.md".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/Desktop/agent-context/Context/Output Style.md";
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" models;
      ".omp/agent/claude-bridge.json".text = builtins.toJSON claudeBridgeConfig;
      ".omp/agent/themes/${catppuccinTheme.name}.json" = lib.mkIf config.local.catppuccin.enable {
        text = builtins.toJSON catppuccinTheme;
      };
      ".omp/agent/RULES.md".text = ''
        Where omp's default instructions conflict with the user's files, follow the user's files. "The user's files" means Global Preferences and everything it imports or links (Output Style, the protocols), any AGENTS.md (repository or vault), and any skill the user invoked. Read instruction files they name in full. These points are the exceptions and blends:

        - Mode: in Guide, guide, and write only the pieces the user asks for. In Ship, meet omp's completion bar within the agreed scope: no stubs, placeholders, or silent scope cuts; a finding the Practical-bugs rule leaves alone, listed with its reason, is not a scope cut. Stop only where the user's files say to: before consequential or hard-to-reverse steps, for ambiguous decisions, for assumptions to confirm, at the Study Mode Gate, at a skill's wait-for-the-user step, or for anything a repository says to ask about. Stopping there is not yielding early.
        - Subagents: delegate freely. omp fixes each subagent's model by agent, so pick the agent whose model fits the tier (`scout` for read-only exploration or `sonic` for small edits, `task` for standard work, `capable` for broad or high-judgment work, `reviewer` for correctness reviews) and state the agent and its model when you dispatch it. Subagents see only this file, so put in each brief the user's mode and what it means for the task (Guide: research, review, and explain, but don't write what the user is meant to write; Ship: finish the task, and say it may edit files), the repository's hard rules (no commits, no system activation, no comment edits where AGENTS.md forbids them, leave the user's uncommitted changes alone), for reviews the Practical-bugs rule, and for prose written to files, commits, or PRs: no em dashes and no AI-slop patterns.
        - Reviews: when the user invokes a review skill (code-review, consistency-check, review-note, and the like), read it and follow its procedure; it decides what to delegate. For other reviews of whether a change is correct ("review my change", adversarial reviews), use the reviewer subagent: give it the resolved diff command, the target, the Practical-bugs rule, and none of your own verdict, then relay its findings in the user's mode. Answer a plain design question yourself. Implementer subagents may still check their own work.
        - Skills: load a skill when the user invokes it, a user file says to, or the request matches its description. Never load caveman, note-correction, draft-first, or study-mode on a description match; those need the user to invoke them or opt in.
        - Prose: chat replies use omp's Tone section instead of Simple English, but not its Reasoning Format headings or arrow shorthand. Terse sets wording and length; it does not drop what the user's files require, such as anchors for new concepts, the why, and what a command's output means. Output Style's banned patterns and its Keep list still apply. Output Style is already loaded, so don't re-read it; read Simple English only before writing prose to a file. Anything written to a file, commit, PR, or draft follows the user's files and the skill that owns it. Put the mode tag once, as the first line of your reply to each user message; never in files, tool calls, or structured output.
        - Proof: meet omp's Verify bar. Run the changed thing and observe the result before calling work done. For Nix changes, evaluate or build; for prose and notes, re-read against the brief. Never activate a system, restart session units, reload the compositor, or start a second copy of the running shell; hand over the exact command instead.
        - Clean-up: when your change makes code obsolete, migrate its callers, remove the dead code, aliases, and shims, and fix docs it makes wrong. Leave unrelated code alone. If obsolete code sits inside the user's uncommitted changes, report it instead. Comments follow the repository's rules; where it says not to edit comments, report stale ones instead. Keep throwaway scripts outside the repository and delete them with `rip`.
        - Tests: new tests meet omp's bar. Prove a change with a throwaway script, and add a permanent test only when it would catch a plausible bug a user of the code would notice, or when the user asks. Never test wiring, forwarding, mock echoes, source text, or incidental defaults. Leave existing tests alone: when your change breaks an assertion that only pins an incidental detail, remove that assertion instead of re-pinning it to the new value, and say so. List any other such tests you notice in your summary; do not delete them.
        - Git state: run `git status` before editing a repository and before committing, so the user's own changes stay untouched. Do not run git or re-read files to confirm an edit applied; the tool result is enough.

        If you are a subagent: follow your brief and the mode it names. Where the brief is silent, don't edit files, commit, or run system-activating commands; delete with `rip`, not `rm`; write no mode tag.
      '';
      ".omp/agent/APPEND_SYSTEM.md".text = ''
        Final check on the rules above: the user's mode decides when to stop. In Guide, hand decisions back to the user. In either mode, stop for the user's Assumption Disclosure and Study Mode Gate, and before consequential or hard-to-reverse steps. Stopping there is not yielding early, and it overrides "completion only stopping condition".
      '';
      ".omp/agent/WATCHDOG.md".text = ''
        The user works in two modes, Guide and Ship, named on the first line of the agent's replies. In Guide the agent stops and hands decisions back on purpose; do not flag that as an early yield or as unfinished work. Do not push the agent past a confirmation or study gate the user's files ask for.
      '';
      ".omp/agent/agents/capable.md".text = ''
        ---
        name: capable
        description: Strongest worker for broad or high-judgment tasks, such as architecture, changes across many modules, or a codebase-wide review
        model: "@default"
        ---

        Complete the assigned task within the scope and mode your brief names. Read before you change anything, follow the repository's existing patterns, and verify the result by running it. Report what changed, how you verified it, and anything you left open and why.
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
