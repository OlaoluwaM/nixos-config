jq -cn \
	--arg local "$(date '+%a %b %d  %H:%M')" \
	--arg birmingham "$(TZ='Europe/London' date '+%H:%M')" \
	--arg lagos "$(TZ='Africa/Lagos' date '+%H:%M')" \
	--arg sanfrancisco "$(TZ='America/Los_Angeles' date '+%H:%M')" \
	'{
    local: $local,
    birmingham: $birmingham,
    lagos: $lagos,
    sanfrancisco: $sanfrancisco
  }'
