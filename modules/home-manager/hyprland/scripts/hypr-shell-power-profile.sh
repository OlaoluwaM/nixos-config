#!/usr/bin/env bash
set -euo pipefail

read_powerprofilesctl() {
	powerprofilesctl get 2>/dev/null || true
}

read_asusctl() {
	command -v asusctl >/dev/null 2>&1 || return 1
	asusctl profile get 2>/dev/null |
		sed -n 's/.*Active profile: //p' |
		head -n 1
}

current_profile() {
	profile="$(read_powerprofilesctl)"

	if [ -z "$profile" ]; then
		profile="$(read_asusctl || true)"
	fi

	if [ -z "$profile" ]; then
		printf 'Unavailable\n'
		return
	fi

	case "$profile" in
	power-saver) printf 'Saver\n' ;;
	balanced) printf 'Balanced\n' ;;
	performance) printf 'Performance\n' ;;
	Quiet | Balanced | Performance) printf '%s\n' "$profile" ;;
	*) printf '%s\n' "$profile" ;;
	esac
}

cycle_powerprofilesctl() {
	current="$(read_powerprofilesctl)"

	case "$current" in
	power-saver) next="balanced" ;;
	balanced) next="performance" ;;
	performance) next="power-saver" ;;
	*) next="balanced" ;;
	esac

	powerprofilesctl set "$next"
}

cycle_asusctl() {
	command -v asusctl >/dev/null 2>&1 || return 1
	asusctl profile -n
}

case "${1:-status}" in
status)
	current_profile
	;;
cycle)
	if ! cycle_powerprofilesctl 2>/dev/null; then
		cycle_asusctl 2>/dev/null || true
	fi
	current_profile
	;;
*)
	printf 'Usage: %s [status|cycle]\n' "$0" >&2
	exit 64
	;;
esac
