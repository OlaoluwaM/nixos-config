# shellcheck shell=bash

# Beginner orientation:
#
# This helper gives the quick settings panel one simple command for power mode.
# It hides the differences between two possible backends:
# - powerprofilesctl, from power-profiles-daemon, common on many Linux systems
# - asusctl, useful on ASUS laptops
#
# The QML quick settings card calls:
#   hypr-shell-power-profile status
# to display the current mode, and:
#   hypr-shell-power-profile cycle
# to move to the next mode.
# It can also call:
#   hypr-shell-power-profile set balanced
# when the user clicks one exact profile button.
#
# If neither backend works, the script prints "Unavailable" instead of failing.

# Try the standard Linux power profile command first.
read_powerprofilesctl() {
	powerprofilesctl get 2>/dev/null || true
}

# ASUS-specific fallback. Nix can put asusctl on any machine, so checking only
# for the command is not enough. Only try it when the hardware says it is ASUS.
is_asus_machine() {
	vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
	case "$vendor" in
	*ASUS*) return 0 ;;
	*) return 1 ;;
	esac
}

read_asusctl() {
	command -v asusctl >/dev/null 2>&1 || return 1
	is_asus_machine || return 1

	profile="$(asusctl profile get 2>/dev/null || true)"
	case "$profile" in
	Quiet | Balanced | Performance) printf '%s\n' "$profile" ;;
	*)
		printf '%s\n' "$profile" |
			sed -n -e 's/.*Active profile: //p' -e 's/.*Active profile is //p' |
			head -n 1
		;;
	esac
}

# Produce the short label shown in the UI.
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

# Cycle through the three standard power-profiles-daemon modes.
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

# ASUS fallback cycle command.
cycle_asusctl() {
	command -v asusctl >/dev/null 2>&1 || return 1
	is_asus_machine || return 1
	asusctl profile next
}

set_powerprofilesctl() {
	case "$1" in
	power-saver | balanced | performance) ;;
	*)
		printf 'hypr-shell-power-profile: unknown profile: %s\n' "$1" >&2
		return 64
		;;
	esac

	powerprofilesctl set "$1"
}

set_asusctl() {
	command -v asusctl >/dev/null 2>&1 || return 1
	is_asus_machine || return 1

	case "$1" in
	power-saver) profile="Quiet" ;;
	balanced) profile="Balanced" ;;
	performance) profile="Performance" ;;
	*)
		printf 'hypr-shell-power-profile: unknown profile: %s\n' "$1" >&2
		return 64
		;;
	esac

	asusctl profile set "$profile"
}

case "${1:-status}" in
status)
	current_profile
	;;
cycle)
	changed=0
	if cycle_powerprofilesctl 2>/dev/null; then
		changed=1
	elif cycle_asusctl 2>/dev/null; then
		changed=1
	fi
	current_profile
	if [ "$changed" -eq 0 ]; then
		printf 'hypr-shell-power-profile: no usable power profile backend found\n' >&2
		exit 1
	fi
	;;
set)
	if [ -z "${2:-}" ]; then
		printf 'hypr-shell-power-profile: set needs a profile\n' >&2
		exit 64
	fi

	changed=0
	if set_powerprofilesctl "$2" 2>/dev/null; then
		changed=1
	elif set_asusctl "$2" 2>/dev/null; then
		changed=1
	fi
	current_profile
	if [ "$changed" -eq 0 ]; then
		printf 'hypr-shell-power-profile: no usable power profile backend found\n' >&2
		exit 1
	fi
	;;
*)
	printf 'Usage: %s [status|cycle|set PROFILE]\n' "$0" >&2
	exit 64
	;;
esac
