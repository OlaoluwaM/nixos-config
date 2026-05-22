# shellcheck shell=bash

state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
mkdir -p "$state_dir"

cpu_state="$state_dir/cpu-sample"
read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
cpu="0"

if [ -r "$cpu_state" ]; then
	read -r prev_total prev_idle <"$cpu_state" || true
	total_delta=$((total - prev_total))
	idle_delta=$((idle_all - prev_idle))
	if [ "$total_delta" -gt 0 ]; then
		cpu=$((100 * (total_delta - idle_delta) / total_delta))
	fi
fi

printf '%s %s\n' "$total" "$idle_all" >"$cpu_state"

mem="$(
	awk '
    /MemTotal:/ { total = $2 }
    /MemAvailable:/ { available = $2 }
    END {
      if (total > 0) {
        printf "%.0f", ((total - available) * 100) / total
      } else {
        printf "0"
      }
    }
  ' /proc/meminfo
)"

temp="$(
	sensors -u 2>/dev/null | awk '
    /^[^[:space:]].*:/ {
      label = $0
      sub(/:$/, "", label)
      preferred = (label ~ /^(Package id 0|Tctl|Tdie|CPU|Composite)$/)
    }
    preferred && /temp[0-9]+_input:/ {
      printf "%.0f", $2
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' || true
)"

if [ -z "$temp" ]; then
	temp="$(
		sensors -u 2>/dev/null | awk '
      /temp[0-9]+_input:/ {
        printf "%.0f", $2
        exit
      }
    ' || true
	)"
fi

if [ -z "$temp" ]; then
	temp="--"
fi

volume="$(pamixer --get-volume 2>/dev/null || true)"
if [ -z "$volume" ]; then
	volume="--"
else
	volume="${volume}%"
fi

muted="$(pamixer --get-mute 2>/dev/null || printf 'false')"

brightness="$(
	brightnessctl -m 2>/dev/null |
		awk -F, '{ gsub(/%/, "", $4); print $4; exit }' || true
)"
if [ -z "$brightness" ]; then
	brightness="--"
else
	brightness="${brightness}%"
fi

battery="AC"
bat_dir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' 2>/dev/null | head -n 1 || true)"
if [ -n "$bat_dir" ] && [ -r "$bat_dir/capacity" ]; then
	capacity="$(cat "$bat_dir/capacity")"
	state="$(cat "$bat_dir/status" 2>/dev/null || printf 'Unknown')"
	battery="${capacity}% ${state}"
fi

network="$(
	nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null |
		awk -F: '$2 == "connected" && ($1 == "wifi" || $1 == "ethernet") { print $3; exit }' || true
)"
if [ -z "$network" ]; then
	network="offline"
fi

vpn="$(
	nmcli -t -f TYPE,NAME connection show --active 2>/dev/null |
		awk -F: '$1 == "vpn" || $1 == "wireguard" { print $2; exit }' || true
)"
if [ -z "$vpn" ]; then
	vpn="off"
fi

bluetooth="$(
	bluetoothctl show 2>/dev/null |
		awk -F': ' '/Powered:/ { print tolower($2); exit }' || true
)"
if [ -z "$bluetooth" ]; then
	bluetooth="off"
fi

power_profile="$(hypr-shell-power-profile status 2>/dev/null || true)"
if [ -z "$power_profile" ]; then
	power_profile="Unavailable"
fi

media_status="$(playerctl status 2>/dev/null || true)"
media_title="$(
	playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null |
		sed 's/^ - //; s/ - $//' || true
)"
if [ -z "$media_title" ]; then
	media_title="No media"
fi
if [ -z "$media_status" ]; then
	media_status="Stopped"
fi

jq -cn \
	--arg cpu "$cpu" \
	--arg mem "$mem" \
	--arg temp "$temp" \
	--arg volume "$volume" \
	--arg muted "$muted" \
	--arg brightness "$brightness" \
	--arg battery "$battery" \
	--arg network "$network" \
	--arg vpn "$vpn" \
	--arg bluetooth "$bluetooth" \
	--arg powerProfile "$power_profile" \
	--arg mediaStatus "$media_status" \
	--arg mediaTitle "$media_title" \
	'{
    cpu: $cpu,
    mem: $mem,
    temp: $temp,
    volume: $volume,
    muted: $muted,
    brightness: $brightness,
    battery: $battery,
    network: $network,
    vpn: $vpn,
    bluetooth: $bluetooth,
    powerProfile: $powerProfile,
    mediaStatus: $mediaStatus,
    mediaTitle: $mediaTitle
  }'
