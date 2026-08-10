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
# If neither backend works, `status` prints "Unavailable" instead of failing.
# When a backend works, every command prints one normalized profile:
# performance, balanced, or power-saver.

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
adapter_dir="${HYPR_SHELL_POWER_PROFILE_LIB_DIR:-"$script_dir/power-profile-adapters"}"
backends=""

validate_profile() {
	case "$1" in
	power-saver | balanced | performance) return 0 ;;
	*)
		printf 'hypr-shell-power-profile: unknown profile: %s\n' "$1" >&2
		return 64
		;;
	esac
}

select_backend() {
	for backend in $backends; do
		if backend_call "$backend" available; then
			printf '%s\n' "$backend"
			return 0
		fi
	done

	return 1
}

# Generic backend dispatcher. `backend_call asusctl get` becomes
# `asusctl_get`, but only after confirming the backend name is in the trusted
# backend list so arbitrary function names cannot be invoked through arguments.
backend_call() {
	backend="$1"
	operation="$2"
	shift 2

	case " $backends " in
	*" $backend "*) ;;
	*) return 1 ;;
	esac

	"${backend}_${operation}" "$@"
}

current_profile() {
	backend="$(select_backend 2>/dev/null || true)"
	if [ -z "$backend" ]; then
		printf 'Unavailable\n'
		return
	fi

	backend_call "$backend" get || printf 'Unavailable\n'
}

no_backend_error() {
	printf 'hypr-shell-power-profile: no usable power profile backend found\n' >&2
	exit 1
}

# Adapter filenames are ordered as NN-name.sh. The numeric prefix controls
# backend preference; the suffix becomes the backend function prefix.
for adapter in "$adapter_dir"/*.sh; do
	[ -e "$adapter" ] || {
		printf 'hypr-shell-power-profile: no backend adapters found in: %s\n' "$adapter_dir" >&2
		exit 1
	}

	adapter_name="${adapter##*/}"
	adapter_name="${adapter_name%.sh}"
	backend="${adapter_name#*-}"
	backends="${backends:+$backends }$backend"
	# shellcheck source=/dev/null
	. "$adapter"
done

case "${1:-status}" in
status)
	current_profile
	;;
cycle)
	backend="$(select_backend 2>/dev/null || true)"
	[ -n "$backend" ] || {
		printf 'Unavailable\n'
		no_backend_error
	}

	backend_call "$backend" cycle || {
		backend_call "$backend" get 2>/dev/null || printf 'Unavailable\n'
		exit 1
	}
	backend_call "$backend" get || printf 'Unavailable\n'
	;;
set)
	if [ -z "${2:-}" ]; then
		printf 'hypr-shell-power-profile: set needs a profile\n' >&2
		exit 64
	fi
	validate_profile "$2" || exit $?

	backend="$(select_backend 2>/dev/null || true)"
	[ -n "$backend" ] || {
		printf 'Unavailable\n'
		no_backend_error
	}

	backend_call "$backend" set "$2" || {
		backend_call "$backend" get 2>/dev/null || printf 'Unavailable\n'
		exit 1
	}
	backend_call "$backend" get || printf 'Unavailable\n'
	;;
*)
	printf 'Usage: %s [status|cycle|set PROFILE]\n' "$0" >&2
	exit 64
	;;
esac
