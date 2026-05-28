# shellcheck shell=bash

# Beginner orientation for this script:
#
# This script gathers the command-backed system values shown in the Quickshell
# top bar and quick settings popover. It prints one compact JSON object to
# stdout. The QML file runs this script every couple seconds, parses the JSON,
# and passes each field to StatusController.updateStatus().
#
# Plain English data flow:
#   Linux commands -> this shell script -> JSON text -> StatusController -> UI
#
# Audio, media, and battery intentionally do not live here. Those values come
# from native Quickshell services in QML: PipeWire, MPRIS, and UPower.
#
# This script is intentionally defensive. Many values may not exist in a VM:
# brightness can be missing, temperature sensors can be missing, Bluetooth can
# be unavailable, and NetworkManager may be absent. In those cases the script
# prints friendly fallback values like "N/A", "Off", or "Offline" instead of
# crashing.
#
# Relevant sources:
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

# NetworkManager CLI. This grabs the first connected Wi-Fi or Ethernet
# connection name. If none is connected, show "Offline".
network="$(
	nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null |
		awk -F: '$2 == "connected" && ($1 == "wifi" || $1 == "ethernet") { print $3; exit }' || true
)"
if [ -z "$network" ]; then
	network="Offline"
fi

# Airplane mode is represented by all rfkill devices being soft-blocked. If the
# host has no rfkill devices, keep the UI off instead of treating it as blocked.
airplane_mode="$(
	rfkill -n -o SOFT list 2>/dev/null |
		awk '
      { total++; if ($1 == "blocked") blocked++ }
      END {
        if (total > 0 && total == blocked) print "true";
        else print "false";
      }
    ' || true
)"
if [ -z "$airplane_mode" ]; then
	airplane_mode="false"
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

# Manual caffeine mode is backed by a user service that holds a systemd idle
# inhibitor. Automatic media inhibition is handled by a separate daemon and is
# not reflected here.
caffeine_manual="false"
if [ "$(hypr-shell-caffeine status 2>/dev/null || true)" = "on" ]; then
	caffeine_manual="true"
fi

# jq -cn builds JSON safely. Each --arg passes a shell variable into jq as a
# string. The final quoted block names the JSON keys that shell.qml expects.
#
# If you add a new key here, also add the matching assignment in
# StatusController.updateStatus().
jq -cn \
	--arg cpu "$cpu" \
	--arg mem "$mem" \
	--arg temp "$temp" \
	--arg brightness "$brightness" \
	--argjson airplaneMode "$airplane_mode" \
	--arg network "$network" \
	--arg vpn "$vpn" \
	--arg bluetooth "$bluetooth" \
	--arg bluetoothDevice "$bluetooth_device" \
	--arg powerProfile "$power_profile" \
	--argjson caffeineManual "$caffeine_manual" \
	'{
    cpu: $cpu,
    mem: $mem,
    temp: $temp,
    brightness: $brightness,
    airplaneMode: $airplaneMode,
    network: $network,
    vpn: $vpn,
    bluetooth: $bluetooth,
    bluetoothDevice: $bluetoothDevice,
    powerProfile: $powerProfile,
    caffeineManual: $caffeineManual
  }'
