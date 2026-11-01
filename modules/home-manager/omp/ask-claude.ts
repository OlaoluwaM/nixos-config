import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";

const MAX_PROMPT_BYTES = 100_000;
const TIMEOUT_MS = 30 * 60 * 1000;

const API_KEY_VARS = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"];

const READ_ONLY_GIT =["git diff", "git status", "git log", "git show"];

const SYSTEM_PROMPT = [
	"Another coding agent asked you to review its work.",
	"You cannot edit files. Bash is limited to read-only git diff, status, log and show; run them as plain 'git <subcommand>' from the working directory, with no -C flag.",
	"Project settings are not loaded, so start by reading the repository's AGENTS.md or CLAUDE.md, if either exists, and judge the change against its conventions.",
	"Read the code you need yourself. Report findings ranked by severity, each with file:line, what goes wrong in practice, and a suggested fix. If nothing is worth changing, say so plainly.",
].join(" ");

interface ClaudeResult {
	result?: string;
	is_error?: boolean;
	subtype?: string;
	session_id?: string;
	num_turns?: number;
	duration_ms?: number;
	permission_denials?: { tool_name: string; tool_input?: { command?: string } }[];
}

const factory: CustomToolFactory = pi => ({
	name: "ask_claude",
	label: "Ask Claude",
	description:
		"Ask Claude Code for a read-only review or second opinion. Claude starts with none of this conversation: say what to review (files, commit range, or the working-tree diff), what the change is meant to do, and what to focus on. Claude reads the repository and runs git diff/status/log/show itself, so name files and commits instead of pasting them. To follow up on an earlier review, pass its sessionId.",
	loadMode: "essential",
	approval: "read",
	parameters: pi.zod.object({
		prompt: pi.zod.string().describe("The full review request. Claude has no other context."),
		model: pi.zod
			.enum(["sonnet", "opus", "fable"])
			.optional()
			.describe("sonnet (default) for routine reviews; opus or fable for a first-pass adversarial or final review."),
		effort: pi.zod.enum(["low", "medium", "high", "xhigh", "max"]).optional().describe("Reasoning effort. Default high."),
		sessionId: pi.zod.string().optional().describe("Resume an earlier ask_claude session to follow up on its review."),
		cwd: pi.zod.string().optional().describe("Repository to review. Defaults to the session's working directory."),
	}),

	async execute(_toolCallId, params, onUpdate, _ctx, signal) {
		const promptBytes = Buffer.byteLength(params.prompt);
		if (promptBytes > MAX_PROMPT_BYTES) {
			throw new Error(
				`Prompt is ${promptBytes} bytes; keep it under ${MAX_PROMPT_BYTES}. Name files and commits instead of pasting them.`,
			);
		}

		const model = params.model ?? "sonnet";
		const effort = params.effort ?? "high";

		const args = [
			...API_KEY_VARS.flatMap(name => ["-u", name]),
			"claude",
			"-p",
			"--output-format",
			"json",
			"--model",
			model,
			"--effort",
			effort,
			"--permission-mode",
			"dontAsk",
			"--setting-sources",
			"user",
			"--strict-mcp-config",
			"--disallowedTools",
			"Bash(*--output*)",
			"--tools",
			"Read",
			"Grep",
			"Glob",
			"Bash",
			"--allowedTools",
			...READ_ONLY_GIT.map(command => `Bash(${command}:*)`),
			"--append-system-prompt",
			SYSTEM_PROMPT,
		];
		if (params.sessionId) args.push("--resume", params.sessionId);
		args.push("--", params.prompt);

		onUpdate?.({
			content: [{ type: "text", text: `Claude ${model} (${effort}) is reviewing...` }],
			details: { model, effort },
		});

		const run = await pi.exec("env", args, { signal, cwd: params.cwd ?? pi.cwd, timeout: TIMEOUT_MS });
		if (run.killed) {
			throw new Error("ask_claude was cancelled or ran past its 30-minute limit");
		}

		let output: ClaudeResult;
		try {
			output = JSON.parse(run.stdout);
		} catch {
			throw new Error(run.stderr.trim() || run.stdout.trim() || `claude exited with code ${run.code}`);
		}
		if (output.is_error || !output.result) {
			throw new Error(output.result || `Claude Code failed (${output.subtype ?? `exit ${run.code}`})`);
		}

		const denied = (output.permission_denials ?? []).map(d => d.tool_input?.command ?? d.tool_name);
		const footer = [`Claude session: ${output.session_id}. Pass it as sessionId to follow up.`];
		if (denied.length > 0) footer.push(`Denied tool calls: ${denied.join("; ")}`);

		return {
			content: [{ type: "text", text: `${output.result}\n\n${footer.join("\n")}` }],
			details: {
				model,
				effort,
				sessionId: output.session_id,
				turns: output.num_turns,
				durationMs: output.duration_ms,
				denied,
			},
		};
	},
});

export default factory;
