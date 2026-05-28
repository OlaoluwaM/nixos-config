#!/usr/bin/env bash
set -euo pipefail

# Beginner orientation:
#
# This is a tiny bridge from Hyprland keybinds to Quickshell.
#
# Problem it solves:
# Hyprland keybinds can run shell commands, but they cannot directly call a QML
# function inside shell.qml. So this script writes a command into a small file.
# shell.qml polls that file every 250ms and runs the matching QML action.
#
# Current use:
#   hypr-shell-popup quick-settings
# opens the quick settings popover.
#
# Volume commands are routed through Quickshell so PipeWire remains the single
# place where shell UI volume changes happen.
#
# The first value written to the file is a timestamp token. That token makes
# every write unique, so shell.qml can tell "this is a new command" instead of
# repeatedly handling the same old file content.

state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
state_file="$state_dir/popup-command"

mkdir -p "$state_dir"

case "${1:-}" in
quick-settings | quickSettings)
	command="quickSettings"
	;;
audio-up | audio-down | audio-mute | osd-volume | osd-brightness | osd-keyboard | osd-mute)
	command="$1"
	;;
*)
	printf 'Usage: %s <quick-settings|audio-up|audio-down|audio-mute|osd-volume|osd-brightness|osd-keyboard|osd-mute>\n' "$0" >&2
	exit 64
	;;
esac

printf '%s %s\n' "$(date +%s%N)" "$command" >"$state_file"
