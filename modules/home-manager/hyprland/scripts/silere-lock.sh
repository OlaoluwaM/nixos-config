# shellcheck shell=bash

# Every lock in the session starts here: hypridle's lock_cmd runs this for
# each `loginctl lock-session` (idle, Super+L, suspend, the shell's Lock
# entries). It keeps three promises: a lock request never ends in an unlocked
# session, a failure never leaves a session nobody can unlock, and there are
# never two lock clients at once.
#
# writeShellApplication runs this under `set -euo pipefail`, so anything that
# may fail is captured (`rc=0; cmd || rc=$?`). An abort at the wrong moment
# would skip the lock entirely. Every wait is counted in `sleep 0.1` steps,
# never measured against the clock: suspend can freeze the machine mid-wait,
# and a clock that counts the time asleep would give up on a healthy lock.

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"

# Decisions go to the journal at real priorities, so
# `journalctl --user -t silere-lock -p warning` lists every fallback. Once
# the lock descriptor is open the logger runs with it closed, like every
# child except hyprlock.
log() {
	local priority="$1"
	shift
	if [ -n "${lockfd:-}" ]; then
		systemd-cat -t silere-lock -p "$priority" printf '%s\n' "$*" {lockfd}>&- ||
			printf 'silere-lock: %s\n' "$*" >&2
	else
		systemd-cat -t silere-lock -p "$priority" printf '%s\n' "$*" ||
			printf 'silere-lock: %s\n' "$*" >&2
	fi
}

# 1. A scope of its own. hypridle runs lock_cmd inside hypridle.service, which
# restarts on failure and whenever its settings change, and a restart would
# take the lock down with it. In scope mode systemd-run returns the command's
# own status, so the inner run touches a marker first: no marker means
# systemd-run itself failed (an unreachable user bus, say), and the session
# still has to lock, unscoped.
if [ -z "${SILERE_LOCK_SCOPE_MARKER:-}" ]; then
	scope_dir=""
	rc=0
	scope_dir="$(mktemp -d "$runtime_dir/silere-lock-scope.XXXXXX")" || rc=$?
	if [ "$rc" -eq 0 ]; then
		marker="$scope_dir/started"
		rc=0
		SILERE_LOCK_SCOPE_MARKER="$marker" systemd-run --user --scope --collect --quiet -- "$0" "$@" || rc=$?
		started=0
		if [ -e "$marker" ]; then
			started=1
		fi
		rm -rf -- "$scope_dir" || true
		if [ "$rc" -eq 0 ] || [ "$started" -eq 1 ]; then
			exit "$rc"
		fi
		log warning "systemd-run failed with status $rc; locking without a scope"
	else
		log warning "could not create a scope marker in $runtime_dir; locking without a scope"
	fi
else
	: >"$SILERE_LOCK_SCOPE_MARKER" || true
	unset SILERE_LOCK_SCOPE_MARKER
fi

# 2. One lock at a time. The flock sits on a dedicated descriptor, held for
# the wrapper's whole life and through the exec into hyprlock. Every other
# child gets it closed ({lockfd}>&-): anything that outlived the wrapper while
# holding it would make every later lock request skip.
rc=0
exec {lockfd}>"$runtime_dir/silere-lock.lock" || rc=$?
if [ "$rc" -ne 0 ]; then
	unset lockfd
	log warning "falling back to hyprlock: could not open $runtime_dir/silere-lock.lock"
	exec systemd-cat -t silere-lock hyprlock
fi

# flock locks the inherited descriptor itself, so it is the one child that
# must keep it open.
rc=0
flock -n "$lockfd" || rc=$?
if [ "$rc" -eq 1 ]; then
	log info "a lock is already running; nothing to do"
	exit 0
elif [ "$rc" -ne 0 ]; then
	log warning "flock failed with status $rc; locking anyway"
fi

# A hyprlock started outside this wrapper only counts while the session
# reads locked: one that lingers holding nothing must not turn locking off.
rc=0
pgrep -x -u "$UID" hyprlock >/dev/null {lockfd}>&- || rc=$?
if [ "$rc" -eq 0 ]; then
	locked=""
	locked="$(hyprctl locked 2>/dev/null {lockfd}>&-)" || locked=""
	if [ "$locked" = true ]; then
		log info "hyprlock is already running and the session is locked; nothing to do"
		exit 0
	fi
fi

# exec keeps the PID and the lock descriptor, and systemd-cat files
# hyprlock's own output under the same tag.
log info "locking with hyprlock"
exec systemd-cat -t silere-lock hyprlock
