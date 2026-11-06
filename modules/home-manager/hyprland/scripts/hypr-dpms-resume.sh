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
#    up. The journal shows "Couldn't retry committing output eDP-1 for DPMS =
#    true".
#
# 4. The real problem: Hyprland writes "screen is on" in its notebook BEFORE
#    it tries, and does not erase it when it fails. From then on, every
#    "turn on" request is ignored, because Hyprland thinks the screen is
#    already on. Pressing keys or sending more "turn on" requests does
#    nothing. (Hyprland v0.57.1, CMonitor::setDPMS in src/output/Monitor.cpp.)
#
# The fix: compare Hyprland's notebook with the truth. The kernel keeps its
# own record of whether the screen is really being driven, in
# /sys/class/drm/card*-<name>/enabled. If Hyprland says "on" but the kernel
# says "disabled", Hyprland is stuck. Turning the screen off first makes
# Hyprland write "off" in its notebook, so the following "turn on" is no
# longer ignored and really happens.
#
# On a normal wake both records agree and this script does nothing.
# hypridle's after_sleep_cmd (hypridle.nix) runs it after every wake.

# Wait out the one-second window from step 2. Checking too early could catch
# a screen that is still in the middle of coming back on by itself. The
# journal showed the window lasting up to two seconds.
settle_seconds=3

# If two off-and-on cycles don't help, a third won't either. Stop and say so
# in the journal instead of flashing the screen forever.
max_cycles=2

# Prints the name of every screen that Hyprland thinks is on but the kernel
# has switched off. Prints nothing when all is well, and fails if Hyprland
# can't be asked at all. Failing matters: a script that says "all good"
# whenever it can't reach Hyprland would hide the problem.
stale_outputs() {
  local monitors name connector
  monitors=$(hyprctl monitors -j) || return 1
  jq -e 'type == "array" and length > 0' >/dev/null <<<"$monitors" || return 1

  while IFS= read -r name; do
    for connector in /sys/class/drm/card*-"$name"; do
      if [[ -r $connector/enabled && $(<"$connector/enabled") == disabled ]]; then
        printf '%s\n' "$name"
      fi
    done
  done < <(jq -r '.[] | select(.dpmsStatus and (.disabled | not)) | .name' <<<"$monitors")
}

cycles=0
while true; do
  sleep "$settle_seconds"

  if ! stale=$(stale_outputs); then
    echo "hypr-dpms-resume: cannot read monitor state from Hyprland" >&2
    exit 1
  fi

  if [[ -z $stale ]]; then
    exit 0
  fi

  if ((cycles == max_cycles)); then
    echo "hypr-dpms-resume: still dark after $cycles DPMS cycles: $(tr '\n' ' ' <<<"$stale")" >&2
    exit 1
  fi
  cycles=$((cycles + 1))

  # Off first, then on, one screen at a time, so a screen that is working
  # never flickers. Use the table form with `monitor =`: the short string form
  # (hl.dsp.dpms("off")) is a toggle that flips every screen at once.
  while IFS= read -r name; do
    echo "hypr-dpms-resume: $name reports DPMS on but its connector is disabled; cycling DPMS (cycle $cycles)" >&2
    hyprctl dispatch "hl.dsp.dpms({ action = \"disable\", monitor = \"$name\" })" >/dev/null
    sleep 1
    hyprctl dispatch "hl.dsp.dpms({ action = \"enable\", monitor = \"$name\" })" >/dev/null
  done <<<"$stale"
done
