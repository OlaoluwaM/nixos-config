# shellcheck shell=bash

# Beginner orientation for this script:
#
# This script gathers the system values shown in the Quickshell top bar and
# quick settings popover. It prints one compact JSON object to stdout. The QML
# file runs this script every couple seconds, parses the JSON, and copies each
# field into root.cpuText, root.memText, root.mediaTitle, etc.
#
# Plain English data flow:
#   Linux commands -> this shell script -> JSON text -> shell.qml -> visible UI
#
# This script is intentionally defensive. Many values may not exist in a VM:
# brightness can be missing, battery can be missing, temperature sensors can be
# missing, Bluetooth can be unavailable, and playerctl may find no media player.
# In those cases the script prints friendly fallback values like "N/A", "Off",
# "Offline", or "Stopped" instead of crashing.
#
# Relevant sources:
# - playerctl media metadata/control: https://man.archlinux.org/man/playerctl.1.en
# - jq JSON builder manual: https://jqlang.github.io/jq/manual/

# XDG_RUNTIME_DIR is a per-login-session temporary directory. It is normally
# writable and is a good place for small runtime files. If it is missing or not
# writable, fall back to /tmp so the status script can still run in restricted
# environments such as some sandboxes.
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
if ! mkdir -p "$state_dir" 2>/dev/null || [ ! -w "$state_dir" ]; then
	state_dir="/tmp/hypr-shell-${UID:-$(id -u)}"
	mkdir -p "$state_dir"
fi

# Convert seconds into a display string like 3:07.
# playerctl returns media position as seconds, sometimes with decimals. The UI
# does not need decimal precision, so this rounds down to a whole second.
format_seconds() {
	awk -v seconds="${1:-0}" '
    BEGIN {
      if (seconds !~ /^[0-9]+([.][0-9]+)?$/) {
        seconds = 0
      }
      total = int(seconds)
      printf "%d:%02d", int(total / 60), total % 60
    }
  '
}

# CPU usage is calculated by comparing /proc/stat now with /proc/stat from the
# previous run. That is why this script stores cpu-sample in state_dir.
#
# /proc/stat is cumulative since boot; one reading alone cannot tell "current"
# CPU usage. Two readings tell how much CPU time changed between samples.
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

printf '%s %s\n' "$total" "$idle_all" >"$cpu_state" 2>/dev/null || true

# Memory usage comes from /proc/meminfo. MemAvailable is the kernel's estimate
# of memory that can be used without swapping. This displays used memory as a
# percentage of total memory.
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

# Temperature is read from lm_sensors through "sensors -u". It averages all
# CPU core temps from the coretemp driver (matching what GNOME Vitals shows).
# Falls back to a single preferred sensor, then any sensor.
temp="$(
	sensors 2>/dev/null | awk -F'[+°]' '
    /^Core [0-9]+:/ { sum += $2; n++ }
    END { if (n > 0) printf "%.0f", sum / n; else exit 1 }
  ' || true
)"

if [ -z "$temp" ]; then
	temp="$(
		sensors -u 2>/dev/null | awk '
      /temp[0-9]+_input:/ { sum += $2; n++ }
      END { if (n > 0) printf "%.0f", sum / n; else exit 1 }
    ' || true
	)"
fi

if [ -z "$temp" ]; then
	temp="N/A"
fi

# Audio volume through pamixer. It reports a number like 72, and we append %.
volume="$(pamixer --get-volume 2>/dev/null || true)"
if [ -z "$volume" ]; then
	volume="N/A"
else
	volume="${volume}%"
fi

# pamixer --get-mute returns "true" or "false". The QML uses this to choose the
# muted or unmuted volume icon.
muted="$(pamixer --get-mute 2>/dev/null || printf 'false')"

# Brightness through brightnessctl. The -m output is comma-separated; field 4 is
# the percentage. VMs often do not expose brightness devices, so "N/A" is normal.
brightness="$(
	brightnessctl -m 2>/dev/null |
		awk -F, '{ gsub(/%/, "", $4); print $4; exit }' || true
)"
if [ -z "$brightness" ]; then
	brightness="N/A"
else
	brightness="${brightness}%"
fi

# Battery is read directly from /sys/class/power_supply. If no BAT* device is
# present, assume AC power. Desktop machines and many VMs will show "AC".
battery="AC"
bat_dir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' 2>/dev/null | head -n 1 || true)"
if [ -n "$bat_dir" ] && [ -r "$bat_dir/capacity" ]; then
	capacity="$(cat "$bat_dir/capacity")"
	state="$(cat "$bat_dir/status" 2>/dev/null || printf 'Unknown')"
	battery="${capacity}% ${state}"
fi

battery_hours="--"
battery_minutes="--"
if [ -n "$bat_dir" ] && [ -r "$bat_dir/status" ]; then
	_bat_status=$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")
	if [ "$_bat_status" = "Discharging" ]; then
		_energy=$(cat "$bat_dir/energy_now" 2>/dev/null || cat "$bat_dir/charge_now" 2>/dev/null || echo "")
		_power=$(cat "$bat_dir/power_now" 2>/dev/null || cat "$bat_dir/current_now" 2>/dev/null || echo "")
		if [ -n "$_energy" ] && [ -n "$_power" ] && [ "$_power" -gt 0 ] 2>/dev/null; then
			_total_minutes=$((_energy * 60 / _power))
			battery_hours=$((_total_minutes / 60))
			battery_minutes=$((_total_minutes % 60))
		fi
	fi
fi

# NetworkManager CLI. This grabs the first connected Wi-Fi or Ethernet
# connection name. If none is connected, show "Offline".
network="$(
	nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null |
		awk -F: '$2 == "connected" && ($1 == "wifi" || $1 == "ethernet") { print $3; exit }' || true
)"
if [ -z "$network" ]; then
	network="Offline"
fi

# VPN status is also read from NetworkManager. It checks active connections
# whose type is vpn or wireguard.
vpn="$(
	nmcli -t -f TYPE,NAME connection show --active 2>/dev/null |
		awk -F: '$1 == "vpn" || $1 == "wireguard" { print $2; exit }' || true
)"
if [ -z "$vpn" ]; then
	vpn="Off"
fi

# Bluetooth: controller power state + connected device name (if any).
bluetooth="$(
	bluetoothctl show 2>/dev/null |
		awk -F': ' '/Powered:/ { print tolower($2); exit }' || true
)"
if [ -z "$bluetooth" ]; then
	bluetooth="Off"
fi

bluetooth_device=""
if [ "$bluetooth" = "yes" ]; then
	bluetooth_device="$(
		bluetoothctl devices Connected 2>/dev/null |
			awk '{ $1=""; $2=""; sub(/^[ \t]+/, ""); print; exit }' || true
	)"
fi

# Power profile is delegated to hypr-shell-power-profile. That helper knows how
# to read power-profiles-daemon first and asusctl as a fallback.
power_profile="$(hypr-shell-power-profile status 2>/dev/null || true)"
if [ -z "$power_profile" ]; then
	power_profile="Unavailable"
fi

# Media player status and metadata through playerctl. playerctl talks to MPRIS,
# a common Linux desktop media-control interface exposed by many players and
# browsers. If there is no active player, these commands return nothing and we
# fall back to "Stopped" / "No media".
media_status="$(playerctl status 2>/dev/null || true)"
media_artist="$(playerctl metadata --format '{{ artist }}' 2>/dev/null || true)"
media_track_title="$(playerctl metadata --format '{{ title }}' 2>/dev/null || true)"
media_album_art="$(playerctl metadata --format '{{ mpris:artUrl }}' 2>/dev/null || true)"
media_position_raw="$(playerctl position 2>/dev/null || true)"
media_length_raw="$(playerctl metadata mpris:length 2>/dev/null || true)"
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
if [ -z "$media_track_title" ]; then
	media_track_title="$media_title"
fi

# Position is seconds. Length is mpris:length, which is microseconds. Convert
# length to seconds first, then format both as M:SS for the QML media capsule.
media_position="$(format_seconds "$media_position_raw")"
media_length_seconds="$(
	awk -v micros="${media_length_raw:-0}" '
    BEGIN {
      if (micros !~ /^[0-9]+$/) {
        micros = 0
      }
      printf "%.0f", micros / 1000000
    }
  '
)"
media_length="$(format_seconds "$media_length_seconds")"

# jq -cn builds JSON safely. Each --arg passes a shell variable into jq as a
# string. The final quoted block names the JSON keys that shell.qml expects.
#
# If you add a new key here, also add a matching property/update line in
# shell.qml's statusProcess block.
jq -cn \
	--arg cpu "$cpu" \
	--arg mem "$mem" \
	--arg temp "$temp" \
	--arg volume "$volume" \
	--arg muted "$muted" \
	--arg brightness "$brightness" \
	--arg battery "$battery" \
	--arg batteryHours "$battery_hours" \
	--arg batteryMinutes "$battery_minutes" \
	--arg network "$network" \
	--arg vpn "$vpn" \
	--arg bluetooth "$bluetooth" \
	--arg bluetoothDevice "$bluetooth_device" \
	--arg powerProfile "$power_profile" \
	--arg mediaStatus "$media_status" \
	--arg mediaTitle "$media_title" \
	--arg mediaArtist "$media_artist" \
	--arg mediaTrackTitle "$media_track_title" \
	--arg mediaAlbumArt "$media_album_art" \
	--arg mediaPosition "$media_position" \
	--arg mediaLength "$media_length" \
	'{
    cpu: $cpu,
    mem: $mem,
    temp: $temp,
    volume: $volume,
    muted: $muted,
    brightness: $brightness,
    battery: $battery,
    batteryHours: $batteryHours,
    batteryMinutes: $batteryMinutes,
    network: $network,
    vpn: $vpn,
    bluetooth: $bluetooth,
    bluetoothDevice: $bluetoothDevice,
    powerProfile: $powerProfile,
    mediaStatus: $mediaStatus,
    mediaTitle: $mediaTitle,
    mediaArtist: $mediaArtist,
    mediaTrackTitle: $mediaTrackTitle,
    mediaAlbumArt: $mediaAlbumArt,
    mediaPosition: $mediaPosition,
    mediaLength: $mediaLength
  }'
