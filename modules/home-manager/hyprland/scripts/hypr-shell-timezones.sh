# shellcheck shell=bash

# Beginner orientation:
#
# This script prints the clock value used by shell.qml. It is separate from
# hypr-shell-status.sh because time is simple and updates on its own schedule.
#
# The output is JSON, for example:
#   {"local":"May 22 1:33 PM"}
#
# shell.qml reads this JSON in timezoneProcess and copies `local` into
# root.clockText for the center top-bar clock.

jq -cn \
	--arg local "$(date '+%b %-d %-I:%M %p')" \
	'{
    local: $local
  }'
