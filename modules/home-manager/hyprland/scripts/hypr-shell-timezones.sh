# shellcheck shell=bash

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
