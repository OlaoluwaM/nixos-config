#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
state_file="$state_dir/popup-command"

mkdir -p "$state_dir"

case "${1:-}" in
quick-settings | quickSettings)
	command="quickSettings"
	;;
*)
	printf 'Usage: %s quick-settings\n' "$0" >&2
	exit 64
	;;
esac

printf '%s %s\n' "$(date +%s%N)" "$command" >"$state_file"
