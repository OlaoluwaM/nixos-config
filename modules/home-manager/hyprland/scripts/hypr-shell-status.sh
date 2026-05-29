# shellcheck shell=bash

# Beginner orientation for this script:
#
# This script gathers the command-backed system values shown in the Quickshell
# top bar and quick settings popover. It prints one JSON object to stdout. The
# QML file runs this script every couple seconds, parses the JSON, and hands it
# to StatusController.updateStatus().
#
# Plain English data flow:
#   Linux commands -> this shell script -> JSON text -> StatusController -> UI
#
# Design rule (important):
#   Export RAW, ATOMIC facts. One fact per field. Never fold a boolean into a
#   sentinel string (no "Offline"/"Off"/"N/A"). Numbers are emitted as real JSON
#   numbers, or null when the source is unavailable. Strings are emitted empty
#   ("") when absent. The UI decides what to display and how to format it; it is
#   free to ignore fields it does not need.
#
# The JSON is grouped by domain (cpu, memory, temperature, brightness, network,
# vpn, rfkill, bluetooth, power, caffeine) so related facts stay together
# without being collapsed into one another.
#
# Audio, media, and battery intentionally do not live here. Those values come
# from native Quickshell services in QML: PipeWire, MPRIS, and UPower.
#
# This script is intentionally defensive. Many values may not exist in a VM:
# brightness can be missing, temperature sensors can be missing, Bluetooth can
# be unavailable, and NetworkManager may be absent. In those cases the field is
# null/false/"" instead of crashing. The script runs under writeShellApplication
# (set -euo pipefail), so every fallible command is guarded with `|| true`, a
# default, or a conditional.
#
# Relevant sources:
# - jq JSON builder manual: https://jqlang.github.io/jq/manual/
# - nmcli getter mode (-g): clean scalar values with no colon-escaping
# - rfkill -J: machine-readable radio block state

# Small helpers -------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
# yes/no -> JSON bool literal
yn() { [ "${1:-}" = "yes" ] && printf 'true' || printf 'false'; }

# XDG_RUNTIME_DIR is a per-login-session temporary directory. It is normally
# writable and is a good place for small runtime files. If it is missing or not
# writable, fall back to /tmp so the status script can still run in restricted
# environments such as some sandboxes.
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell"
if ! mkdir -p "$state_dir" 2>/dev/null || [ ! -w "$state_dir" ]; then
	state_dir="/tmp/hypr-shell-${UID:-$(id -u)}"
	mkdir -p "$state_dir"
fi

# ── CPU ────────────────────────────────────────────────────────────────────
# CPU usage is calculated by comparing /proc/stat now with /proc/stat from the
# previous run. That is why this script stores cpu-sample in state_dir.
#
# /proc/stat is cumulative since boot; one reading alone cannot tell "current"
# CPU usage. Two readings tell how much CPU time changed between samples. Using
# the stored previous sample avoids an in-script sleep on every poll.
cpu_state="$state_dir/cpu-sample"
read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
cpu=0

if [ -r "$cpu_state" ]; then
	read -r prev_total prev_idle <"$cpu_state" || true
	total_delta=$((total - ${prev_total:-0}))
	idle_delta=$((idle_all - ${prev_idle:-0}))
	if [ "$total_delta" -gt 0 ]; then
		cpu=$((100 * (total_delta - idle_delta) / total_delta))
	fi
fi
printf '%s %s\n' "$total" "$idle_all" >"$cpu_state" 2>/dev/null || true

# Load average and logical CPU count are raw extra facts (UI may compute
# load-vs-cores). loadavg is a float; emit it untouched.
load1=null
load5=null
load15=null
if [ -r /proc/loadavg ]; then
	read -r load1 load5 load15 _ </proc/loadavg || {
		load1=null
		load5=null
		load15=null
	}
fi
cpu_count="$(nproc 2>/dev/null || printf 'null')"

# ── Memory ───────────────────────────────────────────────────────────────
# /proc/meminfo values are in kB. MemAvailable is the kernel's estimate of
# memory usable without swapping; it is the correct basis for "used" (MemFree
# alone ignores reclaimable cache and overstates usage). Raw kB are exported
# alongside the percentages so the UI can show either.
mem_total=0
mem_avail=0
swap_total=0
swap_free=0
if [ -r /proc/meminfo ]; then
	eval "$(awk '
		/^MemTotal:/     { print "mem_total="$2 }
		/^MemAvailable:/ { print "mem_avail="$2 }
		/^SwapTotal:/    { print "swap_total="$2 }
		/^SwapFree:/     { print "swap_free="$2 }
	' /proc/meminfo)"
fi
mem_used=$((mem_total - mem_avail))
if [ "$mem_total" -gt 0 ]; then
	mem_used_pct=$(((100 * mem_used + mem_total / 2) / mem_total))
else
	mem_used_pct=null
fi
swap_used=$((swap_total - swap_free))
if [ "$swap_total" -gt 0 ]; then
	swap_used_pct=$(((100 * swap_used + swap_total / 2) / swap_total))
else
	swap_used_pct=null
fi

# ── Temperature ────────────────────────────────────────────────────────────
# Average the per-core CPU temperatures (coretemp "Core N" sensors), matching
# the GNOME Vitals average reading rather than the hotter single package sensor.
# Read straight from sysfs (no lm_sensors dependency, stable labels, no stderr
# noise). Falls back to the package sensor, then the x86_pkg_temp thermal zone,
# when no per-core labels exist (e.g. AMD k10temp or VMs) -> null if none found.
temp_milli=""
temp_label=""
temp_sum=0
temp_count=0
for label_file in /sys/class/hwmon/hwmon*/temp*_label; do
	[ -e "$label_file" ] || continue
	case "$(cat "$label_file" 2>/dev/null || true)" in
	"Core "*)
		core_milli="$(cat "${label_file%_label}_input" 2>/dev/null || true)"
		if [ -n "$core_milli" ]; then
			temp_sum=$((temp_sum + core_milli))
			temp_count=$((temp_count + 1))
		fi
		;;
	esac
done
if [ "$temp_count" -gt 0 ]; then
	temp_milli=$((temp_sum / temp_count))
	temp_label="Core average"
fi
# Fallback 1: the single package sensor.
if [ -z "$temp_milli" ]; then
	for label_file in /sys/class/hwmon/hwmon*/temp*_label; do
		[ -e "$label_file" ] || continue
		if [ "$(cat "$label_file" 2>/dev/null || true)" = "Package id 0" ]; then
			temp_milli="$(cat "${label_file%_label}_input" 2>/dev/null || true)"
			temp_label="Package id 0"
			break
		fi
	done
fi
# Fallback 2: the x86_pkg_temp thermal zone.
if [ -z "$temp_milli" ]; then
	for zone in /sys/class/thermal/thermal_zone*; do
		[ -e "$zone/type" ] || continue
		if [ "$(cat "$zone/type" 2>/dev/null || true)" = "x86_pkg_temp" ]; then
			temp_milli="$(cat "$zone/temp" 2>/dev/null || true)"
			temp_label="x86_pkg_temp"
			break
		fi
	done
fi
if [ -n "$temp_milli" ]; then
	temp_c=$(((temp_milli + 500) / 1000))
else
	temp_c=null
fi

# ── Brightness ─────────────────────────────────────────────────────────────
# Read raw + max from sysfs and compute percent ourselves (brightnessctl's
# percent is rounded). First backlight device wins. VMs have no backlight -> null.
bright_raw=null
bright_max=null
bright_pct=null
for backlight in /sys/class/backlight/*; do
	[ -e "$backlight/brightness" ] || continue
	r="$(cat "$backlight/brightness" 2>/dev/null || true)"
	m="$(cat "$backlight/max_brightness" 2>/dev/null || true)"
	if [ -n "$r" ] && [ -n "$m" ] && [ "$m" -gt 0 ]; then
		bright_raw="$r"
		bright_max="$m"
		bright_pct=$(((100 * r + m / 2) / m))
	fi
	break
done

# ── Network (NetworkManager) ────────────────────────────────────────────────
# Atomic facts: master radio switches, link state, the authoritative primary
# connection (resolved via the default route so docker/virbr bridges are
# ignored), and the active Wi-Fi AP details.
net_enabled=false
net_online=false
net_state=""
net_connectivity=""
wifi_radio_on=false
wifi_hw_on=false
wwan_radio_on=false
wwan_hw_on=false
p_device=""
p_type=""
p_name=""
p_state=null
p_metered=""
p_ip4=""
p_gateway=""
p_ip6=""
w_ssid=""
w_signal=null
w_security=""
w_freq=""
w_chan=null
w_rate=""
if have nmcli; then
	[ "$(nmcli networking 2>/dev/null || true)" = enabled ] && net_enabled=true

	# STATE:CONNECTIVITY:WIFI-HW:WIFI:WWAN-HW:WWAN (values: enabled/disabled/missing)
	gen="$(nmcli -t -f STATE,CONNECTIVITY,WIFI-HW,WIFI,WWAN-HW,WWAN general 2>/dev/null || true)"
	IFS=: read -r net_state net_connectivity wifi_hw wifi_sw wwan_hw wwan_sw <<<"$gen" || true
	[ "${wifi_sw:-}" = enabled ] && wifi_radio_on=true
	[ "${wifi_hw:-}" = enabled ] && wifi_hw_on=true
	[ "${wwan_sw:-}" = enabled ] && wwan_radio_on=true
	[ "${wwan_hw:-}" = enabled ] && wwan_hw_on=true

	# The authoritative connection is the one carrying the default route.
	def_dev="$(ip -o -4 route show default 2>/dev/null |
		awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true)"
	if [ -n "$def_dev" ]; then
		net_online=true
		p_device="$def_dev"
		p_type="$(nmcli -g GENERAL.TYPE device show "$def_dev" 2>/dev/null || true)"
		p_name="$(nmcli -g GENERAL.CONNECTION device show "$def_dev" 2>/dev/null || true)"
		# GENERAL.STATE reads like "100 (connected)"; keep the leading code.
		p_state_raw="$(nmcli -g GENERAL.STATE device show "$def_dev" 2>/dev/null || true)"
		p_state_num="${p_state_raw%% *}"
		[ -n "$p_state_num" ] && p_state="$p_state_num"
		p_metered="$(nmcli -g GENERAL.METERED device show "$def_dev" 2>/dev/null || true)"
		p_ip4="$(nmcli -g IP4.ADDRESS device show "$def_dev" 2>/dev/null || true)"
		p_gateway="$(nmcli -g IP4.GATEWAY device show "$def_dev" 2>/dev/null || true)"
		# IP6.ADDRESS is an array field: -g backslash-escapes ':' and joins with
		# " | ". Strip the escaping; the UI can split on " | ".
		p_ip6="$(nmcli -g IP6.ADDRESS device show "$def_dev" 2>/dev/null | sed 's/\\//g' || true)"
	fi

	# Active Wi-Fi AP (the row whose IN-USE column is "*").
	if [ "$p_type" = wifi ] || { [ -z "$p_type" ] && [ "$wifi_radio_on" = true ]; }; then
		w_line="$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,FREQ,CHAN,RATE device wifi 2>/dev/null |
			awk -F: '$1 == "*" { print; exit }' || true)"
		if [ -n "$w_line" ]; then
			# nmcli -t escapes ':' inside values as '\:'; a raw IFS=: split would
			# mangle any SSID/security string containing a colon. Swap escaped
			# colons for a unit-separator sentinel, split, then restore them.
			w_safe="${w_line//\\:/$'\x1f'}"
			IFS=: read -r _ w_ssid w_sig w_security w_freq w_ch w_rate <<<"$w_safe" || true
			w_ssid="${w_ssid//$'\x1f'/:}"
			w_security="${w_security//$'\x1f'/:}"
			# signal/chan feed --argjson, so accept them only when numeric.
			[[ "${w_sig:-}" =~ ^[0-9]+$ ]] && w_signal="$w_sig"
			[[ "${w_ch:-}" =~ ^[0-9]+$ ]] && w_chan="$w_ch"
		fi
	fi
fi

# ── VPN / WireGuard ──────────────────────────────────────────────────────
# NetworkManager-managed VPN/WireGuard first; then a raw wg-quick tunnel that
# NM would not know about.
vpn_on=false
vpn_name=""
vpn_type=""
if have nmcli; then
	# Iterate active connections by name (-g yields clean, unescaped values) and
	# match the first VPN/WireGuard/tunnel by its connection.type. Avoids the
	# colon-escaping pitfall of splitting a multi-field terse row when a
	# connection name contains a colon.
	while IFS= read -r conn; do
		[ -n "$conn" ] || continue
		c_type="$(nmcli -g connection.type connection show "$conn" 2>/dev/null || true)"
		case "$c_type" in
		*vpn* | *wireguard* | *tun*)
			vpn_on=true
			vpn_name="$conn"
			vpn_type="$c_type"
			break
			;;
		esac
	done < <(nmcli -g NAME connection show --active 2>/dev/null || true)
fi
if [ "$vpn_on" = false ] && have wg; then
	wg_if="$(wg show interfaces 2>/dev/null | awk '{ print $1; exit }' || true)"
	if [ -n "$wg_if" ]; then
		vpn_on=true
		vpn_name="$wg_if"
		vpn_type="wireguard"
	fi
fi

# ── rfkill (radio block state + airplane mode) ───────────────────────────────
# There is no single "airplane mode" flag on Linux. Export the raw per-radio
# block state and derive airplane mode as "devices exist AND all are blocked".
rf="$(rfkill -J 2>/dev/null || printf '{"rfkilldevices":[]}')"
rf_blocked() {
	# true if any device of the given type is soft- or hard-blocked
	printf '%s' "$rf" |
		jq -e --arg t "$1" 'any(.rfkilldevices[]?; .type == $t and (.soft == "blocked" or .hard == "blocked"))' \
			>/dev/null 2>&1 && printf 'true' || printf 'false'
}
wifi_blocked="$(rf_blocked wlan)"
bt_blocked="$(rf_blocked bluetooth)"
wwan_blocked="$(rf_blocked wwan)"
airplane_mode="$(printf '%s' "$rf" |
	jq -r '(.rfkilldevices | length > 0) and all(.rfkilldevices[]; .soft == "blocked" or .hard == "blocked")' \
		2>/dev/null || printf 'false')"

# ── Bluetooth ────────────────────────────────────────────────────────────
# Controller power/scan state plus an array of every connected device with its
# battery (when reported) and bluez icon. Every bluetoothctl call is wrapped in
# `timeout` because it can hang on a busy/initializing DBus.
bt_available=false
bt_powered=false
bt_discoverable=false
bt_discovering=false
bt_alias=""
bt_devices="[]"
if have bluetoothctl; then
	bt_show="$(timeout 2 bluetoothctl show 2>/dev/null || true)"
	if [ -n "$bt_show" ]; then
		bt_available=true
		bt_powered="$(yn "$(printf '%s\n' "$bt_show" | awk -F': ' '/^[[:space:]]*Powered:/ { print $2; exit }')")"
		bt_discoverable="$(yn "$(printf '%s\n' "$bt_show" | awk -F': ' '/^[[:space:]]*Discoverable:/ { print $2; exit }')")"
		bt_discovering="$(yn "$(printf '%s\n' "$bt_show" | awk -F': ' '/^[[:space:]]*Discovering:/ { print $2; exit }')")"
		bt_alias="$(printf '%s\n' "$bt_show" | awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')"
	fi

	if [ "$bt_powered" = true ]; then
		while read -r _ mac name; do
			[ -z "${mac:-}" ] && continue
			info="$(timeout 2 bluetoothctl info "$mac" 2>/dev/null || true)"
			[ -z "$info" ] && continue
			icon="$(printf '%s\n' "$info" | awk -F': ' '/^[[:space:]]*Icon:/ { print $2; exit }')"
			# "Battery Percentage: 0x55 (85)" -> the decimal in parens is authoritative.
			batt="$(printf '%s\n' "$info" | awk -F'[()]' '/Battery Percentage:/ { print $2; exit }')"
			[ -n "$batt" ] && batt_json="$batt" || batt_json=null
			obj="$(jq -n --arg name "$name" --arg mac "$mac" --arg icon "$icon" --argjson battery "$batt_json" \
				'{ name: $name, mac: $mac, batteryPercent: $battery, icon: $icon }')"
			bt_devices="$(jq -n --argjson a "$bt_devices" --argjson o "$obj" '$a + [$o]')"
		done < <(timeout 2 bluetoothctl devices Connected 2>/dev/null || true)
	fi
fi

# ── Power profile ──────────────────────────────────────────────────────────
# Raw backend profile string + the list of available profiles. Try
# power-profiles-daemon, then the vendor-neutral ACPI platform_profile, then
# the asusctl-aware helper. Casing is left as the backend reports it.
pp_profile=""
pp_source=""
pp_available="[]"
if have powerprofilesctl; then
	pp_profile="$(powerprofilesctl get 2>/dev/null || true)"
	[ -n "$pp_profile" ] && pp_source=powerprofilesctl
	pp_available="$(powerprofilesctl list 2>/dev/null |
		awk -F': ' '/^[* ] [a-z]/ { gsub(/[* ]/, "", $1); print $1 }' |
		jq -R . | jq -cs . 2>/dev/null || printf '[]')"
fi
if [ -z "$pp_profile" ] && [ -r /sys/firmware/acpi/platform_profile ]; then
	pp_profile="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)"
	pp_source=platform_profile
	if [ -r /sys/firmware/acpi/platform_profile_choices ]; then
		pp_available="$(tr ' ' '\n' </sys/firmware/acpi/platform_profile_choices |
			sed '/^$/d' | jq -R . | jq -cs . 2>/dev/null || printf '[]')"
	fi
fi
if [ -z "$pp_profile" ] && have hypr-shell-power-profile; then
	pp_profile="$(hypr-shell-power-profile status 2>/dev/null || true)"
	pp_source=helper
fi

# ── Caffeine (manual idle inhibitor) ────────────────────────────────────────
# Backed by a user service holding a systemd idle inhibitor. Automatic media
# inhibition is handled by a separate daemon and is not reflected here.
caffeine_manual=false
if have hypr-shell-caffeine; then
	[ "$(hypr-shell-caffeine status 2>/dev/null || true)" = on ] && caffeine_manual=true
fi

# ── Assemble JSON ────────────────────────────────────────────────────────
# Each domain is built as its own object, then combined. If you add a field
# here, add the matching assignment in StatusController.updateStatus().
cpu_json="$(jq -n \
	--argjson percent "$cpu" \
	--argjson load1 "$load1" --argjson load5 "$load5" --argjson load15 "$load15" \
	--argjson count "$cpu_count" \
	'{ percent: $percent, loadAvg1: $load1, loadAvg5: $load5, loadAvg15: $load15, count: $count }')"

memory_json="$(jq -n \
	--argjson totalKb "$mem_total" --argjson availableKb "$mem_avail" \
	--argjson usedKb "$mem_used" --argjson usedPercent "$mem_used_pct" \
	--argjson swapTotalKb "$swap_total" --argjson swapUsedKb "$swap_used" \
	--argjson swapUsedPercent "$swap_used_pct" \
	'{ totalKb: $totalKb, availableKb: $availableKb, usedKb: $usedKb, usedPercent: $usedPercent,
	   swapTotalKb: $swapTotalKb, swapUsedKb: $swapUsedKb, swapUsedPercent: $swapUsedPercent }')"

temperature_json="$(jq -n --argjson celsius "$temp_c" --arg label "$temp_label" \
	'{ celsius: $celsius, sensorLabel: $label }')"

brightness_json="$(jq -n \
	--argjson percent "$bright_pct" --argjson raw "$bright_raw" --argjson max "$bright_max" \
	'{ percent: $percent, raw: $raw, max: $max }')"

network_json="$(jq -n \
	--argjson enabled "$net_enabled" --argjson online "$net_online" \
	--arg state "$net_state" --arg connectivity "$net_connectivity" \
	--argjson wifiRadioOn "$wifi_radio_on" --argjson wifiHwOn "$wifi_hw_on" \
	--argjson wwanRadioOn "$wwan_radio_on" --argjson wwanHwOn "$wwan_hw_on" \
	--arg pDevice "$p_device" --arg pType "$p_type" --arg pName "$p_name" \
	--argjson pState "$p_state" --arg pMetered "$p_metered" \
	--arg pIp4 "$p_ip4" --arg pGateway "$p_gateway" --arg pIp6 "$p_ip6" \
	--arg ssid "$w_ssid" --argjson signal "$w_signal" --arg security "$w_security" \
	--arg freq "$w_freq" --argjson chan "$w_chan" --arg rate "$w_rate" \
	'{
		enabled: $enabled, online: $online, state: $state, connectivity: $connectivity,
		wifiRadioOn: $wifiRadioOn, wifiHwOn: $wifiHwOn, wwanRadioOn: $wwanRadioOn, wwanHwOn: $wwanHwOn,
		primary: { device: $pDevice, type: $pType, name: $pName, state: $pState,
		           metered: $pMetered, ip4: $pIp4, ip4Gateway: $pGateway, ip6: $pIp6 },
		wifi: { ssid: $ssid, signal: $signal, security: $security, freq: $freq, chan: $chan, rate: $rate }
	}')"

vpn_json="$(jq -n --argjson on "$vpn_on" --arg name "$vpn_name" --arg type "$vpn_type" \
	'{ on: $on, name: $name, type: $type }')"

rfkill_json="$(jq -n \
	--argjson wifiBlocked "$wifi_blocked" --argjson bluetoothBlocked "$bt_blocked" \
	--argjson wwanBlocked "$wwan_blocked" --argjson airplaneMode "$airplane_mode" \
	'{ wifiBlocked: $wifiBlocked, bluetoothBlocked: $bluetoothBlocked,
	   wwanBlocked: $wwanBlocked, airplaneMode: $airplaneMode }')"

bluetooth_json="$(jq -n \
	--argjson available "$bt_available" --argjson blocked "$bt_blocked" \
	--argjson powered "$bt_powered" --argjson discoverable "$bt_discoverable" \
	--argjson discovering "$bt_discovering" --arg alias "$bt_alias" \
	--argjson devices "$bt_devices" \
	'{ available: $available, blocked: $blocked, powered: $powered,
	   discoverable: $discoverable, discovering: $discovering, alias: $alias, devices: $devices }')"

power_json="$(jq -n \
	--arg profile "$pp_profile" --argjson available "$pp_available" --arg source "$pp_source" \
	'{ profile: $profile, profilesAvailable: $available, source: $source }')"

caffeine_json="$(jq -n --argjson manual "$caffeine_manual" '{ manual: $manual }')"

jq -cn \
	--argjson cpu "$cpu_json" \
	--argjson memory "$memory_json" \
	--argjson temperature "$temperature_json" \
	--argjson brightness "$brightness_json" \
	--argjson network "$network_json" \
	--argjson vpn "$vpn_json" \
	--argjson rfkill "$rfkill_json" \
	--argjson bluetooth "$bluetooth_json" \
	--argjson power "$power_json" \
	--argjson caffeine "$caffeine_json" \
	'{
		cpu: $cpu, memory: $memory, temperature: $temperature, brightness: $brightness,
		network: $network, vpn: $vpn, rfkill: $rfkill, bluetooth: $bluetooth,
		power: $power, caffeine: $caffeine
	}'
