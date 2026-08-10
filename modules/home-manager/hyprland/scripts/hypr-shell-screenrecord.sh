# shellcheck shell=bash

mode="${1:-area}"
screenrecord_dir="${XDG_VIDEOS_DIR:-"$HOME/Videos"}/Screencasts"
output_file="$screenrecord_dir/screencast-from-$(date +%Y%m%d-%H%M%S).mp4"

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

record() {
	# Guard notifications with `|| true`: under writeShellApplication's `set -e`,
	# a failing notify-send (daemon down, e.g. during a shell restart) would
	# otherwise abort before wf-recorder ever starts, or mask the real exit code.
	notify-send "Recording started" "$output_file" || true

	if wf-recorder "$@" -f "$output_file"; then
		notify_location "Recording saved" "$output_file" "$screenrecord_dir"
	else
		exit_code=$?
		notify-send "Recording failed" "wf-recorder exited with status $exit_code" || true
		exit "$exit_code"
	fi
}

case "$mode" in
area)
	geometry="$(slurp || true)"
	[ -n "$geometry" ] || exit 0
	record -g "$geometry"
	;;
full)
	record
	;;
stop)
	if pkill -INT -x wf-recorder; then
		notify-send "Stopping recording" "Saving the video file now." || true
	else
		notify-send "No recording is running" || true
	fi
	;;
*)
	echo "Usage: $0 [area|full|stop]" >&2
	exit 64
	;;
esac
