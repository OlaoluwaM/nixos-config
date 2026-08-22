# shellcheck shell=bash

mode="${1:-area}"
screenrecord_dir="${XDG_VIDEOS_DIR:-"$HOME/Videos"}/Screencasts"
# Human-readable stamp, second precision: date hyphenated, time dotted, no
# spaces so the name never needs quoting in a terminal.
output_file="$screenrecord_dir/screencast-from-$(date +%Y-%m-%d-%H.%M.%S).mp4"

# State file the shell's Recording service watches (silere.nix points its
# recordingStateFile key here): exists exactly while gpu-screen-recorder
# runs, so the bar's recording pill tracks the actual recording, not this
# script's lifetime. Its content is the start moment as epoch seconds, which
# is how the pill's elapsed timer stays truthful even when the shell
# (re)starts mid-recording. Same runtime state dir convention as
# hypr-shell-caffeine.
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
mkdir -p "$state_dir" 2>/dev/null || true
state_file="$state_dir/recording"

# The login shell exports LIBVA_DRIVER_NAME=nvidia session-wide (for Firefox
# NVDEC), which overrides libva's per-device driver choice everywhere -- it is
# why vainfo reports the decode-only NVIDIA shim on BOTH render nodes even
# with intel-media-driver installed. Inherited here it would make
# gpu-screen-recorder's VAAPI init fail on the Intel iGPU and fall back to
# software encoding, defeating the whole point of the hardware path. Unset it
# for this script only so libva resolves the driver by device again (iHD for
# the Intel node the compositor renders on).
unset LIBVA_DRIVER_NAME

mkdir -p "$screenrecord_dir"

# pgrep/pkill -x match against the kernel's comm field (proc(5)), which is
# capped at 15 bytes -- not the full binary name. "gpu-screen-recorder" is
# 19 characters, so the kernel truncates the running process's comm to
# "gpu-screen-reco". Matching the full name here would silently never find
# the process (pgrep even warns "pattern ... longer than 15 characters will
# result in zero matches" and returns nothing); verified empirically against
# a same-named process on this system. wf-recorder was short enough that
# this never came up.
recorder_comm="gpu-screen-reco"

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
# WxH+X+Y form gpu-screen-recorder's -region expects (width/height first,
# offsets after -- the reverse order of wf-recorder's old -g geometry).
window_geometry() {
	hyprctl activewindow -j |
		jq -er '
      .at as $at
      | .size as $size
      | "\($size[0])x\($size[1])+\($at[0])+\($at[1])"
    '
}

stop_recording() {
	if pkill -INT -x "$recorder_comm"; then
		notify-send "Stopping recording" "Saving the video file now." || true
	else
		notify-send "No recording is running" || true
	fi
}

record() {
	# Guard notifications with `|| true`: under writeShellApplication's `set -e`,
	# a failing notify-send (daemon down, e.g. during a shell restart) would
	# otherwise abort before gpu-screen-recorder ever starts, or mask the real
	# exit code.
	notify-send "Recording started" "$output_file" || true

	# The trap, not paired rm lines, owns cleanup: gpu-screen-recorder can end
	# via saved/failed/signal, and the pill must never stay lit on any of
	# them. Written next-door then moved into place: the shell's watcher
	# reacts the instant the name appears, so the file has to arrive with its
	# epoch content already complete instead of racing a bare create.
	date +%s >"$state_file.next" 2>/dev/null || true
	mv -f "$state_file.next" "$state_file" 2>/dev/null || true
	trap 'rm -f "$state_file" "$state_file.next"' EXIT

	# SIGINT (stop_recording's pkill -INT) is documented by gpu-screen-recorder
	# as "stop and save recording", the same clean-shutdown contract
	# wf-recorder's SIGINT had.
	if gpu-screen-recorder "$@" -o "$output_file"; then
		notify_location "Recording saved" "$output_file" "$screenrecord_dir"
	else
		exit_code=$?
		notify-send "Recording failed" "gpu-screen-recorder exited with status $exit_code" || true
		exit "$exit_code"
	fi
}

# Every start chord doubles as the stop chord: a second press of any record
# bind while gpu-screen-recorder runs ends that recording instead of
# stacking a second one. Checked before slurp/hyprctl on purpose, so
# stopping never detours through a region selection.
case "$mode" in
area | full | window)
	if pgrep -x "$recorder_comm" >/dev/null; then
		stop_recording
		exit 0
	fi
	;;
esac

case "$mode" in
area)
	# gpu-screen-recorder's -region wants WxH+X+Y (see `man
	# gpu-screen-recorder`'s slurp example), not slurp's own default
	# "X,Y WxH" output -- ask slurp for that shape directly instead of
	# reformatting it after the fact.
	geometry="$(slurp -f '%wx%h+%x+%y' || true)"
	[ -n "$geometry" ] || exit 0
	record -w region -region "$geometry"
	;;
full)
	# "screen" records the first monitor found (verified via `man
	# gpu-screen-recorder`); this laptop is single-monitor in practice, same
	# scope wf-recorder's bare invocation covered.
	record -w screen
	;;
window)
	geometry="$(window_geometry || true)"
	[ -n "$geometry" ] || exit 0
	record -w region -region "$geometry"
	;;
stop)
	stop_recording
	;;
*)
	echo "Usage: $0 [area|full|window|stop]" >&2
	exit 64
	;;
esac
