# shellcheck shell=bash

report_failure() {
	local title="$1" message="$2"
	printf '%s: %s\n' "$title" "$message" >&2
	# The shell also serves notifications, so a missing or hung shell
	# needs the compositor's notification path. Bound both attempts.
	if ! timeout --kill-after=1s 2s notify-send --urgency=critical --app-name=Vicinae "$title" "$message"; then
		timeout --kill-after=1s 2s hyprctl notify 3 10000 0 "$title: $message" || true
	fi
}

error_log="$(mktemp)"
trap 'rm -f -- "$error_log"' EXIT
# Vicinae waits synchronously for this process on its UI thread.
# Bound the IPC wait so an unresponsive shell cannot freeze the launcher.
ipc_status=0
reply="$(timeout --kill-after=1s 5s qs ipc -p "$SILERE_SHELL_QML" call power request "$1" 2>"$error_log")" || ipc_status=$?
diagnostics="$(cat "$error_log")"
if [[ -n "$diagnostics" ]]; then
	printf '%s\n' "$diagnostics" >&2
fi
if (( ipc_status == 124 || ipc_status == 137 )); then
	# Killing the client cannot retract a request already sent to the shell.
	report_failure "Power request timed out" \
		"The countdown may still start. Check the shell before trying again."
	exit 1
fi
if (( ipc_status != 0 )); then
	message="Could not reach the shell's power countdown."
	if [[ -n "$diagnostics" ]]; then
		printf -v message '%s\n%s' "$message" "$diagnostics"
	fi
	report_failure "Power action unavailable" "$message"
	exit 1
fi
if [[ "$reply" != "ok" ]]; then
	report_failure "Power action unavailable" "$reply"
	exit 1
fi
