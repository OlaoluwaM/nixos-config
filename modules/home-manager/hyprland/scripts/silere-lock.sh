# shellcheck shell=bash

# Every lock in the session starts here: hypridle's lock_cmd runs this for
# each `loginctl lock-session` (idle, Super+L, suspend, the shell's Lock
# entries). It keeps three promises: a lock request never ends in an unlocked
# session, a failure never leaves a session nobody can unlock, and there are
# never two lock clients at once.
#
# SILERE_LOCK_SCREEN picks the lock (local.hyprland.lockScreen): "hyprlock",
# or "follow-shell" for silere-shell's own lock with hyprlock as its fallback.
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

# The end of every path that locks with hyprlock. systemd-cat exits without
# running its command when it cannot open a journal stream, which would leave
# the session unlocked, so the journal is tried first and hyprlock runs bare
# without it.
run_hyprlock() {
	local rc=0
	if [ -n "${lockfd:-}" ]; then
		systemd-cat -t silere-lock true {lockfd}>&- || rc=$?
	else
		systemd-cat -t silere-lock true || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		exec systemd-cat -t silere-lock hyprlock
	fi
	exec hyprlock
}

# A hung compositor must not hang the lock. timeout runs on the clock, unlike
# the waits below, but only fails safe: a missed answer reads as unlocked
# before a lock starts, and as still locked after one ends.
locked_state() {
	timeout 2 hyprctl locked 2>/dev/null {lockfd}>&-
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
	run_hyprlock
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
	locked="$(locked_state)" || locked=""
	if [ "$locked" = true ]; then
		log info "hyprlock is already running and the session is locked; nothing to do"
		exit 0
	fi
fi

# exec keeps the PID and the lock descriptor, and systemd-cat files
# hyprlock's own output under the same tag (run_hyprlock).
if [ "${SILERE_LOCK_SCREEN:-hyprlock}" != follow-shell ]; then
	log info "locking with hyprlock"
	run_hyprlock
fi

# Hand the session to hyprlock, which misc:allow_session_lock_restore lets
# take over a lock whose client died. Only ever reached once nothing of the
# shell's lock is left: Hyprland ignores a new lock client while an earlier
# lock request is unconfirmed, so a hyprlock started too early could lose its
# request and leave a lockdead screen nobody can clear.
ready_dir=""
fall_back() {
	log warning "falling back to hyprlock: $1"
	if [ -n "$ready_dir" ]; then
		rm -rf -- "$ready_dir" {lockfd}>&- || true
	fi
	run_hyprlock
}

# 3. Start the shell's lock. The ready file lives in a fresh directory so a
# file left from an earlier lock can never read as this one being up.
rc=0
ready_dir="$(mktemp -d "$runtime_dir/silere-lock-ready.XXXXXX" {lockfd}>&-)" || rc=$?
if [ "$rc" -ne 0 ]; then
	ready_dir=""
	fall_back "could not create a ready directory in $runtime_dir"
fi
ready_file="$ready_dir/ready"

# setsid makes the lock its own process group, so whatever it spawns can be
# killed with it. A background child of this shell (no job control) is never
# a group leader, so setsid calls setsid() in place instead of forking; with
# systemd-cat and env also exec'ing in place, $! is qs itself and the group's
# ID. qs gets the shell's own PATH so its probes agree with the bar's. The
# crash handler has to be off from the environment: it starts before
# lock.qml's pragmas apply, and its relaunch keeps the PID, so this wrapper
# would never see the exit. QT_LOGGING_RULES passes through from hypridle's
# environment.
setsid systemd-cat -t silere-lock env \
	SILERE_LOCK_WRAPPER=1 \
	SILERE_LOCK_READY_FILE="$ready_file" \
	NO_COLOR=1 \
	QS_DISABLE_CRASH_HANDLER=1 \
	PATH="$SILERE_SHELL_PATH" \
	"$SILERE_LOCK_QS" -p "$SILERE_LOCK_QML" {lockfd}>&- &
pid=$!

# Kill the lock and everything it spawned, and reap it, before anything else
# may lock: TERM, up to 1s, KILL, then the rest of its group.
stop_lock() {
	kill -TERM "$pid" 2>/dev/null || true
	local i=0
	while [ "$i" -lt 10 ] && kill -0 "$pid" 2>/dev/null; do
		sleep 0.1 {lockfd}>&- || true
		i=$((i + 1))
	done
	kill -KILL "$pid" 2>/dev/null || true
	kill -KILL -- "-$pid" 2>/dev/null || true
	status=0
	wait "$pid" 2>/dev/null || status=$?
}

# 4. Confirm it: up to 3s for the ready file. `hyprctl locked` is no
# substitute, since it reads true as soon as any client asks to lock, before
# a frame, and stays true after that client dies.
i=0
ready=0
reason=""
while :; do
	if [ -e "$ready_file" ]; then
		ready=1
		break
	fi
	if ! kill -0 "$pid" 2>/dev/null; then
		reason="exited before it was ready"
		break
	fi
	if [ "$i" -ge 30 ]; then
		reason="was not ready after 3s"
		break
	fi
	sleep 0.1 {lockfd}>&- || true
	i=$((i + 1))
done
if [ "$ready" -eq 0 ]; then
	stop_lock
	fall_back "the shell's lock $reason (status $status)"
fi
log info "the shell's lock is up (ready after about $((i * 100))ms)"

# 5. Wait for the end. Exit 0 means the user unlocked; anything else,
# including a crash while locked, leaves Hyprland's lockdead screen for
# hyprlock to take over.
status=0
wait "$pid" || status=$?
kill -KILL -- "-$pid" 2>/dev/null || true
if [ "$status" -ne 0 ]; then
	log warning "the shell's lock exited with status $status"
	fall_back "the shell's lock ended without an unlock"
fi
log info "the shell's lock exited with status 0"

# An unlock clears `hyprctl locked` at once, so give it up to 1s. A lock
# request in that second finds the flock still held and is dropped; the user
# is unlocking at that moment.
i=0
while :; do
	locked=""
	locked="$(locked_state)" || locked=""
	if [ "$locked" = false ]; then
		break
	fi
	if [ "$i" -ge 10 ]; then
		log warning "the session still reads locked after the shell's lock exited 0"
		fall_back "the session is still locked after an unlock"
	fi
	sleep 0.1 {lockfd}>&- || true
	i=$((i + 1))
done
rm -rf -- "$ready_dir" {lockfd}>&- || true
