# shellcheck shell=bash

# Why this script exists: sometimes the laptop wakes from suspend and the
# screen stays black, even though everything behind it is running.
#
# What goes wrong, step by step:
#
# 1. Before suspend, hypridle tells Hyprland to turn the screen off
#    (before_sleep_cmd). After waking, it tells Hyprland to turn it back on
#    (after_sleep_cmd).
#
# 2. Right after a wake, for about one second, Hyprland is not allowed to
#    touch the screen. logind (the part of systemd that hands out the screen
#    and keyboard) takes the session away and then gives it back. This
#    happens on every wake and is harmless by itself.
#
# 3. If the "turn on" request arrives inside that one second, it fails.
#    Hyprland tries once more a few milliseconds later, fails again, and gives
#    up. It writes "Couldn't retry committing output eDP-1 for DPMS = true" to
#    its log.
#
# 4. The real problem: Hyprland writes "screen is on" in its notebook BEFORE
#    it tries, and does not erase it when it fails. From then on, every
#    "turn on" request is ignored, because Hyprland thinks the screen is
#    already on. (Hyprland v0.57.1, CMonitor::setDPMS in
#    src/output/Monitor.cpp.)
#
# 5. Why the screen is black and not just frozen: when the session comes
#    back, aquamarine (the library Hyprland drives screens with) switches the
#    screen's hardware back on and shows the last picture it had. That
#    picture is the black fade-out from before the suspend. Hyprland also
#    keeps a black cover over the screen until it sees new pictures reach
#    it, and none do. So the hardware is on, but all it shows is black.
#
# Because of step 5, asking the kernel "is the screen on?" doesn't help: it
# says yes. The only reliable sign is the line from step 3 in Hyprland's own
# log, so this script looks for that line after each wake.
#
# The fix is to turn the screen off and then on again. "Off" makes Hyprland
# write "off" in its notebook, so the "on" that follows is no longer ignored
# and really happens. Closing and opening the lid does the same thing through
# a second suspend, which is how this was confirmed to work.
#
# On a normal wake the log has no such line and this script does nothing.
# hypridle's after_sleep_cmd (hypridle.nix) runs it after every wake.

# Give the wake time to finish so the log lines from steps 2 and 3 are
# written before we read them.
settle_seconds=3

log_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/hyprland.log"

# Prints the name of every screen Hyprland gave up turning on, reading the log
# from byte offset $1 onwards. Every wake starts with "Session got
# deactivated!", so only lines after the last one count: those belong to the
# wake that just happened, not to an older one.
failed_outputs() {
  tail -c "+$(($1 + 1))" "$log_file" | awk '
    /Session got deactivated!/ { delete failed }
    match($0, /Couldn.t retry committing output [^ ]+ for DPMS = true/) {
      name = substr($0, RSTART, RLENGTH)
      sub(/^Couldn.t retry committing output /, "", name)
      sub(/ for DPMS = true$/, "", name)
      failed[name] = 1
    }
    END { for (name in failed) print name }
  '
}

# No HYPRLAND_INSTANCE_SIGNATURE, or debug:disable_logs turned on, means there
# is no log to read. Say so instead of quietly doing nothing: a script that
# can't see the problem must not look like one that found none.
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} || ! -r $log_file ]]; then
  echo "hypr-dpms-resume: cannot read Hyprland's log at $log_file (is debug:disable_logs on?)" >&2
  exit 1
fi

sleep "$settle_seconds"

failed=$(failed_outputs 0)
if [[ -z $failed ]]; then
  exit 0
fi

# Remember where the log ends now. The old failure lines stay in the log
# forever, so the check after the cycle must only look at lines written after
# this point, or it would see the old failure and think the cycle failed too.
offset=$(stat -c %s "$log_file")

# Off first, then on, one screen at a time, so a screen that is working
# never flickers. Use the table form with `monitor =`: the short string form
# (hl.dsp.dpms("off")) is a toggle that flips every screen at once.
while IFS= read -r name; do
  echo "hypr-dpms-resume: Hyprland gave up turning $name on after the wake; cycling DPMS" >&2
  hyprctl dispatch "hl.dsp.dpms({ action = \"disable\", monitor = \"$name\" })" >/dev/null
  sleep 1
  hyprctl dispatch "hl.dsp.dpms({ action = \"enable\", monitor = \"$name\" })" >/dev/null
done <<<"$failed"

sleep "$settle_seconds"

still_failed=$(failed_outputs "$offset")
if [[ -n $still_failed ]]; then
  echo "hypr-dpms-resume: turning on failed again after the cycle: $(tr '\n' ' ' <<<"$still_failed")" >&2
  exit 1
fi
echo "hypr-dpms-resume: DPMS cycle done for: $(tr '\n' ' ' <<<"$failed")" >&2
