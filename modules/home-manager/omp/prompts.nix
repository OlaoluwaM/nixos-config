{ config, lib, ... }:

let
  cfg = config.local.omp;
  home = config.home.homeDirectory;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".omp/agent/AGENTS.md".text = ''
        @~/.omp/agent/context/global-preferences.md

        @~/.omp/agent/context/output-style.md
      '';
      ".omp/agent/context/global-preferences.md".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/Desktop/agent-context/Context/Global Preferences.md";
      ".omp/agent/context/output-style.md".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/Desktop/agent-context/Context/Output Style.md";
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
