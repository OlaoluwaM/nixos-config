# shellcheck shell=bash

# Every lock in the session starts here: hypridle's lock_cmd runs this for
# each `loginctl lock-session` (idle, Super+L, suspend), and the shell's Lock
# entries run it directly. It keeps three promises: a lock request never ends
# in an unlocked session, a failure never leaves a session nobody can unlock,
# and there are never two lock clients at once.
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
# other child. stderr is the last resort, and it is often a journal stream
# too, so it can be gone exactly when the journal is: a failed or broken write
# there must never abort the lock. SIGPIPE is ignored only in that subshell,
# so no lock client inherits it. A journal that hangs instead of failing must
# not hold up the lock either, so each write gets a second.
log() {
	local priority="$1"
	shift
	if [ -n "${lockfd:-}" ]; then
		timeout 1 systemd-cat -t silere-lock -p "$priority" printf '%s\n' "$*" {lockfd}>&- && return 0
	else
		timeout 1 systemd-cat -t silere-lock -p "$priority" printf '%s\n' "$*" && return 0
	fi
	(
		trap '' PIPE
		timeout 1 printf 'silere-lock: %s\n' "$*" >&2
	) || true
}

# A hung compositor must not hang the lock. timeout runs on the clock, unlike
# the waits below, but only fails safe: a missed answer reads as unlocked
# before a lock starts, and as still locked after one ends.
locked_state() {
	timeout 2 hyprctl locked 2>/dev/null {lockfd}>&-
}

# 1. A scope of its own. hypridle runs lock_cmd inside hypridle.service, and
# the shell's Lock entries run this inside silere-shell.service; either
# restarts on failure and whenever its settings change, and a restart would
# take the lock down with it. In scope mode systemd-run returns the command's
# own status, so the inner run touches a marker first: no marker means
# systemd-run itself failed (an unreachable user bus, say), and the session
# still has to lock, unscoped. A user manager that stalls (a daemon-reload
# mid-switch) must not stall the lock either, since a suspend waits for it
# only up to logind's InhibitDelayMaxSec, so the scope gets 2s to start.
#
# Giving up must not leave two wrappers: a scope that starts late would lock
# alongside the unscoped run. Each side writes its flag before reading the
# other's (the inner run "started", the outer one "abandoned"), so at least
# one of them sees the other. An inner run that sees "abandoned" exits 75 at
# once; an outer run that sees "started" waits for the inner one, and locks
# unscoped itself only if that inner run exited 75.
if [ -z "${SILERE_LOCK_SCOPE_DIR:-}" ]; then
	scope_dir=""
	rc=0
	scope_dir="$(mktemp -d "$runtime_dir/silere-lock-scope.XXXXXX")" || rc=$?
	if [ "$rc" -eq 0 ]; then
		SILERE_LOCK_SCOPE_DIR="$scope_dir" systemd-run --user --scope --collect --quiet -- "$0" "$@" &
		run_pid=$!
		i=0
		while [ ! -e "$scope_dir/started" ] && kill -0 "$run_pid" 2>/dev/null && [ "$i" -lt 20 ]; do
			sleep 0.1
			i=$((i + 1))
		done
		if [ ! -e "$scope_dir/started" ] && kill -0 "$run_pid" 2>/dev/null; then
			: >"$scope_dir/abandoned" || true
		fi
		if [ -e "$scope_dir/started" ]; then
			# systemd-run exec'd into the inner run, so this waits out the whole lock
			rc=0
			wait "$run_pid" || rc=$?
			if [ "$rc" -ne 75 ]; then
				rm -rf -- "$scope_dir" || true
				exit "$rc"
			fi
			log warning "the scope started after this run gave up on it; locking without a scope"
		elif [ -e "$scope_dir/abandoned" ]; then
			# the directory stays: a scope that starts late must still find "abandoned"
			log warning "systemd-run did not start a scope within 2s; locking without a scope"
		else
			rc=0
			wait "$run_pid" || rc=$?
			rm -rf -- "$scope_dir" || true
			log warning "systemd-run failed with status $rc; locking without a scope"
		fi
	else
		log warning "could not create a scope marker in $runtime_dir; locking without a scope"
	fi
else
	: >"$SILERE_LOCK_SCOPE_DIR/started" || true
	if [ -e "$SILERE_LOCK_SCOPE_DIR/abandoned" ]; then
		rm -rf -- "$SILERE_LOCK_SCOPE_DIR" || true
		log info "this scope started after its run gave up on it and locked without one; leaving the lock to that run"
		exit 75
	fi
	unset SILERE_LOCK_SCOPE_DIR
fi

# 2. One lock at a time. The flock sits on a dedicated descriptor, held for
# the wrapper's whole life, and the wrapper lives as long as any lock client
# it started. Every child gets it closed ({lockfd}>&-): anything that outlived
# the wrapper while holding it would make every later lock request skip.
rc=0
exec {lockfd}>"$runtime_dir/silere-lock.lock" || rc=$?
guarded=1
if [ "$rc" -ne 0 ]; then
	# Lock unguarded rather than not at all. The descriptor still has to exist,
	# since every child closes it.
	guarded=0
	rc=0
	exec {lockfd}>/dev/null || rc=$?
	if [ "$rc" -ne 0 ]; then
		exec hyprlock
	fi
	log warning "could not open $runtime_dir/silere-lock.lock; locking without the one-lock guard"
fi

if [ "$guarded" -eq 1 ]; then
	# flock locks the inherited descriptor itself, so it is the one child that
	# must keep it open.
	rc=0
	flock -n "$lockfd" || rc=$?
	if [ "$rc" -eq 1 ]; then
		# The holder may be a lock that is ending: the user has just unlocked and
		# its wrapper is still letting go. A request then must lock again once it
		# has, not be dropped. Supervision stops a client still running 2s after
		# an unlock and every wait in a teardown is bounded, so the holder always
		# lets go; this request keeps waiting until it does, or until the session
		# reads locked, which means a lock (the holder's own client, still starting
		# when this request came in) has the session after all. Only an answered
		# "true" ends a request: one Hyprland did not answer waits like "false".
		locked=""
		locked="$(locked_state)" || locked=""
		if [ "$locked" = true ]; then
			log info "a lock is already running; nothing to do"
			exit 0
		fi
		log info "the session does not read locked while a lock holds the guard; waiting for it to end"
		while :; do
			rc=0
			flock -w 1 "$lockfd" || rc=$?
			if [ "$rc" -eq 0 ]; then
				break
			elif [ "$rc" -ne 1 ]; then
				log warning "flock failed with status $rc; locking anyway"
				break
			fi
			locked=""
			locked="$(locked_state)" || locked=""
			if [ "$locked" = true ]; then
				log info "the session locked while this request waited; nothing to do"
				exit 0
			fi
		done
	elif [ "$rc" -ne 0 ]; then
		log warning "flock failed with status $rc; locking anyway"
	fi
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

ready_dir=""
cleanup() {
	if [ -n "$ready_dir" ]; then
		rm -rf -- "$ready_dir" {lockfd}>&- || true
	fi
}
trap cleanup EXIT

# Stop a lock client, and its process group when it has one, and reap it:
# TERM, up to 1s, KILL. Sets status to how it ended.
stop_client() {
	local target="$1" group="$2" i=0
	kill -TERM "$target" 2>/dev/null || true
	while [ "$i" -lt 10 ] && kill -0 "$target" 2>/dev/null; do
		sleep 0.1 {lockfd}>&- || true
		i=$((i + 1))
	done
	kill -KILL "$target" 2>/dev/null || true
	if [ "$group" -eq 1 ]; then
		kill -KILL -- "-$target" 2>/dev/null || true
	fi
	status=0
	wait "$target" 2>/dev/null || status=$?
}

# Wait for a lock client to end. A client that outlives the unlock would keep
# the wrapper, and so the flock, alive and silently turn every later lock off,
# so once the session has read unlocked on two checks a second apart while it
# runs, it is stopped and the lock counts as over (lingered=1). Only a client
# that has been seen locked can linger: before its lock request the session
# reads unlocked too, so one that never gets that far within 10s is stopped
# as failed instead, and until then the session is checked five times a
# second, so a quick unlock is not missed. Both calls need Hyprland to answer
# "false": an unanswered query proves nothing, and stopping a client that may
# hold the lock would leave the lockdead screen. Sets status.
supervise() {
	local target="$1" group="$2" seen="$3" i=0 unlocked=0 state
	lingered=0
	while kill -0 "$target" 2>/dev/null; do
		if [ $((i % 10)) -eq 9 ] || { [ "$seen" -eq 0 ] && [ $((i % 2)) -eq 1 ]; }; then
			state=""
			state="$(locked_state)" || state=""
			if [ "$state" = true ]; then
				seen=1
				unlocked=0
			elif [ "$state" = false ] && [ "$seen" -eq 1 ]; then
				unlocked=$((unlocked + 1))
			else
				unlocked=0
			fi
			if [ "$unlocked" -ge 2 ]; then
				lingered=1
				stop_client "$target" "$group"
				return 0
			fi
			if [ "$seen" -eq 0 ] && [ "$i" -ge 100 ] && [ "$state" = false ]; then
				stop_client "$target" "$group"
				status=124
				return 0
			fi
		fi
		sleep 0.1 {lockfd}>&- || true
		i=$((i + 1))
	done
	status=0
	wait "$target" || status=$?
	if [ "$group" -eq 1 ]; then
		kill -KILL -- "-$target" 2>/dev/null || true
	fi
}

# An unlock clears `hyprctl locked` at once, so give it up to 1s. A lock
# request in that second finds the flock still held and the session unlocked,
# so it waits for this wrapper to let go and then locks (step 2).
reads_unlocked() {
	local i=0 state
	while [ "$i" -le 10 ]; do
		state=""
		state="$(locked_state)" || state=""
		if [ "$state" = false ]; then
			return 0
		fi
		sleep 0.1 {lockfd}>&- || true
		i=$((i + 1))
	done
	return 1
}

# systemd-cat can also stall after the probe, before it exec's its command,
# and a launcher that never becomes hyprlock would be supervised as if it
# were one, behind a lock that may already be dead. So it gets 1s to stop
# being systemd-cat (one that has already exited is left to supervise to
# report). The test is on names hyprlock is not: systemd-cat's, and this
# wrapper's, which the child carries until it execs at all. hyprlock's own
# name is not tested, since a wrapped build changes it.
read -r self_comm <"/proc/$$/comm" || self_comm=""
became_hyprlock() {
	local i=0 comm
	while [ "$i" -lt 10 ]; do
		comm=""
		{ read -r comm <"/proc/$1/comm"; } 2>/dev/null || return 0
		if [ "$comm" != systemd-cat ] && [ "$comm" != "$self_comm" ]; then
			return 0
		fi
		sleep 0.1 {lockfd}>&- || true
		i=$((i + 1))
	done
	return 1
}

# Lock with hyprlock and stay with it until the session is unlocked. A
# hyprlock that dies while locked leaves Hyprland's lockdead screen, which
# only a new client can clear (misc:allow_session_lock_restore lets it take
# over), so it is restarted, a second apart, up to five times. systemd-cat
# exits without running its command when it cannot open a journal stream,
# which would leave the session unlocked, so the journal is tried first and
# hyprlock runs bare without it; a start that fails anyway exits non-zero and
# is retried like a crash.
lock_with_hyprlock() {
	local attempt=1 rc i client
	while :; do
		rc=0
		timeout 1 systemd-cat -t silere-lock true {lockfd}>&- || rc=$?
		if [ "$rc" -eq 0 ]; then
			systemd-cat -t silere-lock hyprlock {lockfd}>&- &
			client=$!
			if ! became_hyprlock "$client"; then
				log warning "systemd-cat did not start hyprlock within 1s; starting it without the journal"
				kill -KILL "$client" 2>/dev/null || true
				wait "$client" 2>/dev/null || true
				hyprlock {lockfd}>&- &
				client=$!
			fi
		else
			hyprlock {lockfd}>&- &
			client=$!
		fi
		supervise "$client" 0 0
		if [ "$lingered" -eq 1 ]; then
			log warning "hyprlock was still running after the unlock; stopped it"
			return 0
		fi
		if [ "$status" -eq 0 ] && reads_unlocked; then
			log info "hyprlock exited after an unlock"
			return 0
		fi
		if [ "$attempt" -ge 5 ]; then
			log err "hyprlock ended without an unlock $attempt times (last status $status); giving up"
			exit 1
		fi
		log warning "hyprlock ended without an unlock (status $status); starting it again"
		attempt=$((attempt + 1))
		i=0
		while [ "$i" -lt 10 ]; do
			sleep 0.1 {lockfd}>&- || true
			i=$((i + 1))
		done
	done
}

if [ "${SILERE_LOCK_SCREEN:-hyprlock}" != follow-shell ]; then
	log info "locking with hyprlock"
	lock_with_hyprlock
	exit 0
fi

# Hand the session to hyprlock. Only ever reached once nothing of the shell's
# lock is left: Hyprland ignores a new lock client while an earlier lock
# request is unconfirmed, so a hyprlock started too early could lose its
# request and leave a lockdead screen nobody can clear.
fall_back() {
	log warning "falling back to hyprlock: $1"
	lock_with_hyprlock
	exit 0
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
# would never see the exit. QT_LOGGING_RULES passes through from the caller's
# environment (hypridle's, or the shell's for its Lock entries). --no-detailed-logs keeps Quickshell's PAM helper from relaying
# PAM's prompt text into the journal, and drops a detailed log file in the
# runtime directory for every lock.
setsid systemd-cat -t silere-lock env \
	SILERE_LOCK_WRAPPER=1 \
	SILERE_LOCK_READY_FILE="$ready_file" \
	NO_COLOR=1 \
	QS_DISABLE_CRASH_HANDLER=1 \
	PATH="$SILERE_SHELL_PATH" \
	"$SILERE_LOCK_QS" --no-detailed-logs -p "$SILERE_LOCK_QML" {lockfd}>&- &
pid=$!

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
	stop_client "$pid" 1
	fall_back "the shell's lock $reason (status $status)"
fi
log info "the shell's lock is up (ready after about $((i * 100))ms)"

# 5. Wait for the end. Exit 0 means the user unlocked; anything else,
# including a crash while locked, leaves Hyprland's lockdead screen for
# hyprlock to take over.
supervise "$pid" 1 1
if [ "$lingered" -eq 1 ]; then
	log warning "the shell's lock was still running after the unlock; stopped it"
	exit 0
fi
if [ "$status" -ne 0 ]; then
	log warning "the shell's lock exited with status $status"
	fall_back "the shell's lock ended without an unlock"
fi
log info "the shell's lock exited with status 0"
if ! reads_unlocked; then
	log warning "the session still reads locked after the shell's lock exited 0"
	fall_back "the session is still locked after an unlock"
fi
