# shellcheck shell=bash

set -euo pipefail

service_name="hypr-shell-caffeine.service"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
if ! mkdir -p "$state_dir" 2>/dev/null || [ ! -w "$state_dir" ]; then
	state_dir="/tmp/hypr-shell-${UID:-$(id -u)}"
	mkdir -p "$state_dir"
fi
pid_file="$state_dir/caffeine-inhibit.pid"

service_exists() {
	systemctl --user cat "$service_name" >/dev/null 2>&1
}

is_active() {
	if service_exists; then
		systemctl --user is-active --quiet "$service_name"
	elif [ -r "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

start_inhibitor() {
	if service_exists; then
		systemctl --user start "$service_name"
		return
	fi

	if is_active; then
		return
	fi

	systemd-inhibit --what=idle --who=HyprShell --why=Manual-caffeine-mode --mode=block sleep infinity &
	printf '%s\n' "$!" >"$pid_file"
}

stop_inhibitor() {
	if service_exists; then
		systemctl --user stop "$service_name"
		return
	fi

	if [ -r "$pid_file" ]; then
		kill "$(cat "$pid_file")" 2>/dev/null || true
		rm -f "$pid_file"
	fi
}

case "${1:-status}" in
status)
	if is_active; then
		printf 'on\n'
	else
		printf 'off\n'
	fi
	;;
toggle)
	if is_active; then
		stop_inhibitor
	else
		start_inhibitor
	fi
	;;
on | enable | start)
	start_inhibitor
	;;
off | disable | stop)
	stop_inhibitor
	;;
*)
	printf 'usage: hypr-shell-caffeine [status|toggle|on|off]\n' >&2
	exit 2
	;;
esac
