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
	notify-send "Recording started" "$output_file"

	if wf-recorder "$@" -f "$output_file"; then
		notify_location "Recording saved" "$output_file" "$screenrecord_dir"
	else
		exit_code=$?
		notify-send "Recording failed" "wf-recorder exited with status $exit_code"
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
		notify-send "Stopping recording" "Saving the video file now."
	else
		notify-send "No recording is running"
	fi
	;;
*)
	echo "Usage: $0 [area|full|stop]" >&2
	exit 64
	;;
esac
