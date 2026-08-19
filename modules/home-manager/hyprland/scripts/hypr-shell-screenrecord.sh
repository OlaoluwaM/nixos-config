# shellcheck shell=bash

mode="${1:-area}"
screenrecord_dir="${XDG_VIDEOS_DIR:-"$HOME/Videos"}/Screencasts"
# Human-readable stamp, second precision: date hyphenated, time dotted, no
# spaces so the name never needs quoting in a terminal.
output_file="$screenrecord_dir/screencast-from-$(date +%Y-%m-%d-%H.%M.%S).mp4"

# State file the shell's Recording service watches (silere.nix points its
# recordingStateFile key here): exists exactly while wf-recorder runs, so the
# bar's recording pill tracks the actual recording, not this script's
# lifetime. Its content is the start moment as epoch seconds, which is how
# the pill's elapsed timer stays truthful even when the shell (re)starts
# mid-recording. Same runtime state dir convention as hypr-shell-caffeine.
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
mkdir -p "$state_dir" 2>/dev/null || true
state_file="$state_dir/recording"

mkdir -p "$screenrecord_dir"

notify_location() {
	local title="$1"
	local body="$2"
	local location="$3"

	(
		action="$(notify-send \
			--app-name "Hypr Shell" \
			--icon folder-videos \
			--action=open="Open Folder" \
			"$title" \
			"$body" || true)"

		if [[ "$action" == "open" ]]; then
			xdg-open "$location" >/dev/null 2>&1 &
		fi
	) &
}

# Same geometry derivation as hypr-shell-screenshot's window mode: Hyprland
# knows the active window position and size; jq turns that JSON into the
# geometry format wf-recorder's -g expects.
window_geometry() {
	hyprctl activewindow -j |
		jq -er '
      .at as $at
      | .size as $size
      | "\($at[0]),\($at[1]) \($size[0])x\($size[1])"
    '
}

stop_recording() {
	if pkill -INT -x wf-recorder; then
		notify-send "Stopping recording" "Saving the video file now." || true
	else
		notify-send "No recording is running" || true
	fi
}

record() {
	# Guard notifications with `|| true`: under writeShellApplication's `set -e`,
	# a failing notify-send (daemon down, e.g. during a shell restart) would
	# otherwise abort before wf-recorder ever starts, or mask the real exit code.
	notify-send "Recording started" "$output_file" || true

	# The trap, not paired rm lines, owns cleanup: wf-recorder can end via
	# saved/failed/signal, and the pill must never stay lit on any of them.
	# Written next-door then moved into place: the shell's watcher reacts the
	# instant the name appears, so the file has to arrive with its epoch
	# content already complete instead of racing a bare create.
	date +%s >"$state_file.next" 2>/dev/null || true
	mv -f "$state_file.next" "$state_file" 2>/dev/null || true
	trap 'rm -f "$state_file" "$state_file.next"' EXIT

	if wf-recorder "$@" -f "$output_file"; then
		notify_location "Recording saved" "$output_file" "$screenrecord_dir"
	else
		exit_code=$?
		notify-send "Recording failed" "wf-recorder exited with status $exit_code" || true
		exit "$exit_code"
	fi
}

# Every start chord doubles as the stop chord: a second press of any record
# bind while wf-recorder runs ends that recording instead of stacking a
# second one. Checked before slurp/hyprctl on purpose, so stopping never
# detours through a region selection.
case "$mode" in
area | full | window)
	if pgrep -x wf-recorder >/dev/null; then
		stop_recording
		exit 0
	fi
	;;
esac

case "$mode" in
area)
	geometry="$(slurp || true)"
	[ -n "$geometry" ] || exit 0
	record -g "$geometry"
	;;
full)
	record
	;;
window)
	geometry="$(window_geometry || true)"
	[ -n "$geometry" ] || exit 0
	record -g "$geometry"
	;;
stop)
	stop_recording
	;;
*)
	echo "Usage: $0 [area|full|window|stop]" >&2
	exit 64
	;;
esac
