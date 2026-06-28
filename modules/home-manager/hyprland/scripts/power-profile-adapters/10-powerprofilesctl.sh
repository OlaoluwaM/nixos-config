# shellcheck shell=bash

normalize_powerprofilesctl() {
	case "$1" in
	power-saver | balanced | performance) printf '%s\n' "$1" ;;
	*) return 1 ;;
	esac
}

powerprofilesctl_get_raw() {
	command -v powerprofilesctl >/dev/null 2>&1 || return 1
	powerprofilesctl get 2>/dev/null
}

powerprofilesctl_available() {
	profile="$(powerprofilesctl_get_raw 2>/dev/null || true)"
	[ -n "$profile" ] || return 1
	normalize_powerprofilesctl "$profile" >/dev/null
}

powerprofilesctl_get() {
	profile="$(powerprofilesctl_get_raw)"
	normalize_powerprofilesctl "$profile"
}

powerprofilesctl_set() {
	validate_profile "$1" || return $?
	powerprofilesctl set "$1"
}

powerprofilesctl_cycle() {
	current="$(powerprofilesctl_get)"

	case "$current" in
	power-saver) next="balanced" ;;
	balanced) next="performance" ;;
	performance) next="power-saver" ;;
	# If the daemon vanished between the availability check and now, $current is
	# empty; fall back to balanced so set -u can't kill the helper on unset $next.
	*) next="balanced" ;;
	esac

	powerprofilesctl_set "$next"
}
