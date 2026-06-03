# shellcheck shell=bash

# Nix can put asusctl on any machine, so checking only for the command is not
# enough. Only try it when the hardware says it is ASUS.
is_asus_machine() {
	vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
	case "$vendor" in
	*ASUS*) return 0 ;;
	*) return 1 ;;
	esac
}

asusctl_get_raw() {
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

normalize_asusctl() {
	case "$1" in
	Quiet | quiet | power-saver) printf 'power-saver\n' ;;
	Balanced | balanced) printf 'balanced\n' ;;
	Performance | performance) printf 'performance\n' ;;
	*) return 1 ;;
	esac
}

asusctl_available() {
	profile="$(asusctl_get_raw 2>/dev/null || true)"
	[ -n "$profile" ] || return 1
	normalize_asusctl "$profile" >/dev/null
}

asusctl_get() {
	profile="$(asusctl_get_raw)"
	normalize_asusctl "$profile"
}

asusctl_set() {
	validate_profile "$1" || return $?

	case "$1" in
	power-saver) profile="Quiet" ;;
	balanced) profile="Balanced" ;;
	performance) profile="Performance" ;;
	esac

	asusctl profile set "$profile"
}

asusctl_cycle() {
	asusctl profile next
}
