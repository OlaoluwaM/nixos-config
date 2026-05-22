# shellcheck shell=bash

# Beginner orientation:
#
# This script prints the clock values used by shell.qml. It is separate from
# hypr-shell-status.sh because time is simple and updates on its own schedule.
#
# The output is JSON, for example:
#   {"local":"May 22 1:33 PM","birmingham":"7:33 PM",...}
#
# shell.qml reads this JSON in timezoneProcess and copies the values into:
# - root.clockText for the center top-bar clock
# - root.localTime for the calendar popover heading
# - root.birminghamTime / root.lagosTime / root.sanFranciscoTime for the
#   world-clock cards

# TZ=... temporarily asks date to format time in that timezone. It only applies
# to the single command where it is written; it does not change your system
# timezone.
jq -cn \
	--arg local "$(date '+%b %-d %-I:%M %p')" \
	--arg birmingham "$(TZ='Europe/London' date '+%-I:%M %p')" \
	--arg lagos "$(TZ='Africa/Lagos' date '+%-I:%M %p')" \
	--arg sanfrancisco "$(TZ='America/Los_Angeles' date '+%-I:%M %p')" \
	'{
    local: $local,
    birmingham: $birmingham,
    lagos: $lagos,
    sanfrancisco: $sanfrancisco
  }'
