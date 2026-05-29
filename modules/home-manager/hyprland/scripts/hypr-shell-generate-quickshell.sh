#!/usr/bin/env bash
set -euo pipefail

# Beginner orientation:
#
# This is an internal helper used by hypr-shell-tty-test.sh.
#
# It does not start Quickshell and it does not preview anything by itself.
# Its only job is to generate a temporary Quickshell config from the editable
# repo copy of the Quickshell QML directory.
#
# Why this helper exists:
# The real GeneratedCommands.qml contains placeholders such as @STATUS_SCRIPT@
# and @BRIGHTNESS_COMMAND@. During a normal Home Manager switch, quickshell.nix
# replaces those placeholders with exact Nix store paths. For host-side TTY
# testing, we are not doing a Home Manager switch, so this helper substitutes
# those placeholders with small wrapper scripts in a temporary runtime folder.
#
# The wrappers call the real host commands. That means the TTY test reads actual
# host values: /proc CPU/memory data, sensors, NetworkManager, brightnessctl,
# etc. Missing host services still show fallback text like N/A or Offline, but
# there is no mock data here.

usage() {
	cat >&2 <<'EOF'
Usage:
  hypr-shell-generate-quickshell [--repo PATH] [--output PATH]

Examples:
  hypr-shell-generate-quickshell --repo ~/Desktop/labs/nixos-config --output /run/user/1000/hypr-shell-tty-test/config

This helper only writes a generated Quickshell config. It does not launch
Quickshell or Hyprland directly.
EOF
}

repo_root="${HYPR_SHELL_REPO:-}"
output_dir=""

while [ "$#" -gt 0 ]; do
	case "$1" in
	--repo)
		if [ "$#" -lt 2 ]; then
			printf 'hypr-shell-generate-quickshell: --repo needs a path\n' >&2
			exit 64
		fi
		repo_root="$2"
		shift 2
		;;
	--output)
		if [ "$#" -lt 2 ]; then
			printf 'hypr-shell-generate-quickshell: --output needs a path\n' >&2
			exit 64
		fi
		output_dir="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'hypr-shell-generate-quickshell: unknown argument: %s\n' "$1" >&2
		usage
		exit 64
		;;
	esac
done

if [ -z "$repo_root" ]; then
	if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
		repo_root="$git_root"
	else
		printf 'hypr-shell-generate-quickshell: could not find repo root.\n' >&2
		printf 'Run from the repo, set HYPR_SHELL_REPO, or pass --repo PATH.\n' >&2
		exit 64
	fi
fi

if [ -z "$output_dir" ]; then
	runtime_root="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell-tty-test"
	if ! mkdir -p "$runtime_root" 2>/dev/null || [ ! -w "$runtime_root" ]; then
		runtime_root="/tmp/hypr-shell-tty-test-${UID:-$(id -u)}"
		mkdir -p "$runtime_root"
	fi
	output_dir="$runtime_root/config"
fi

repo_root="$(realpath "$repo_root")"
output_dir="$(realpath -m "$output_dir")"
qml_dir="$repo_root/modules/home-manager/hyprland/quickshell"
scripts_dir="$repo_root/modules/home-manager/hyprland/scripts"
bin_dir="$(dirname "$output_dir")/bin"

if [ ! -d "$qml_dir" ] || ! ls "$qml_dir"/*.qml >/dev/null 2>&1; then
	printf 'hypr-shell-generate-quickshell: no QML files found in:\n  %s\n' "$qml_dir" >&2
	exit 66
fi

mkdir -p "$output_dir" "$bin_dir"

write_repo_script_wrapper() {
	local name="$1"
	local script_path="$2"
	local output="$bin_dir/$name"
	local quoted_bin_dir
	local quoted_script_path

	if [ ! -f "$script_path" ]; then
		printf 'hypr-shell-generate-quickshell: expected helper script not found:\n  %s\n' "$script_path" >&2
		exit 66
	fi

	printf -v quoted_bin_dir '%q' "$bin_dir"
	printf -v quoted_script_path '%q' "$script_path"
	cat >"$output" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export PATH=${quoted_bin_dir}:"\$PATH"
exec bash ${quoted_script_path} "\$@"
EOF
	chmod +x "$output"
}

write_command_wrapper() {
	local name="$1"
	local command_name="$2"
	local required="${3:-optional}"
	local output="$bin_dir/$name"
	local command_path
	local quoted_command_path

	command_path="$(command -v "$command_name" 2>/dev/null || true)"

	if [ -n "$command_path" ]; then
		printf -v quoted_command_path '%q' "$command_path"
		cat >"$output" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec ${quoted_command_path} "\$@"
EOF
	else
		cat >"$output" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'hypr-shell-generate-quickshell: command not available on host: %s\n' "$command_name" >&2
if [ "$required" = "required" ]; then
	exit 69
fi
exit 0
EOF
	fi

	chmod +x "$output"
}

write_repo_script_wrapper hypr-shell-status "$scripts_dir/hypr-shell-status.sh"
write_repo_script_wrapper hypr-shell-timezones "$scripts_dir/hypr-shell-timezones.sh"
write_repo_script_wrapper hypr-shell-power-profile "$scripts_dir/hypr-shell-power-profile.sh"
write_repo_script_wrapper hypr-shell-caffeine "$scripts_dir/hypr-shell-caffeine.sh"
write_repo_script_wrapper hypr-shell-popup "$scripts_dir/hypr-shell-popup.sh"

write_command_wrapper sh sh required
write_command_wrapper cat cat required
write_command_wrapper awk awk required
write_command_wrapper tr tr required
write_command_wrapper vicinae vicinae
write_command_wrapper airctl airctl
write_command_wrapper overskride overskride
write_command_wrapper hyprshutdown hyprshutdown
write_command_wrapper brightnessctl brightnessctl
write_command_wrapper rfkill rfkill
write_command_wrapper systemctl systemctl required
write_command_wrapper loginctl loginctl required
write_command_wrapper hyprctl hyprctl required
write_command_wrapper notify-send notify-send

if [ "${HYPR_SHELL_TTY_SMOKE:-}" = "1" ]; then
	cat >"$output_dir/shell.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    PanelWindow {
        visible: true
        color: "transparent"
        aboveWindows: true
        implicitWidth: 900
        implicitHeight: 56
        exclusiveZone: 64
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-smoke-test"

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: 8
            color: "#f38ba8"

            Text {
                anchors.centerIn: parent
                text: "Quickshell smoke test"
                color: "#11111b"
                font.pixelSize: 18
                font.bold: true
            }
        }
    }
}
EOF
else
	# Copy all QML files and the qmldir manifest from the source directory.
	# GeneratedCommands.qml gets placeholder substitution below; the rest are
	# copied verbatim.
	for f in "$qml_dir"/*.qml "$qml_dir"/qmldir; do
		[ -f "$f" ] && cp "$f" "$output_dir/$(basename "$f")"
	done

	# Theme.qml is generated by home-manager from local.theme options. Prefer
	# the generated copy so the TTY test uses the same theme as the real session.
	hm_theme="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hyprland/Theme.qml"
	if [ -f "$hm_theme" ]; then
		cp "$hm_theme" "$output_dir/Theme.qml"
	fi
fi

replace_placeholder() {
	local file="$1"
	local placeholder="$2"
	local replacement="$3"
	local escaped_replacement

	[ -f "$file" ] || return 0
	escaped_replacement="$(printf '%s' "$replacement" | sed -e 's/[\/&|\\]/\\&/g')"
	sed -i "s|$placeholder|$escaped_replacement|g" "$file"
}

replace_command_placeholder() {
	local qml_replacement

	qml_replacement="$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
	replace_placeholder "$output_dir/GeneratedCommands.qml" "$1" "$qml_replacement"
}

replace_command_placeholder '@SHELL_COMMAND@' "$bin_dir/sh"
replace_command_placeholder '@CAT_COMMAND@' "$bin_dir/cat"
replace_command_placeholder '@AWK_COMMAND@' "$bin_dir/awk"
replace_command_placeholder '@TR_COMMAND@' "$bin_dir/tr"
replace_command_placeholder '@STATUS_SCRIPT@' "$bin_dir/hypr-shell-status"
replace_command_placeholder '@TIMEZONE_SCRIPT@' "$bin_dir/hypr-shell-timezones"
replace_command_placeholder '@NETWORK_COMMAND@' "$bin_dir/airctl"
replace_command_placeholder '@BLUETOOTH_COMMAND@' "$bin_dir/overskride"
replace_command_placeholder '@POWER_COMMAND@' "$bin_dir/hyprshutdown -t 'Shutting down...' --post-cmd '$bin_dir/systemctl poweroff'"
replace_command_placeholder '@POWER_PROFILE_COMMAND@' "$bin_dir/hypr-shell-power-profile"
replace_command_placeholder '@CAFFEINE_COMMAND@' "$bin_dir/hypr-shell-caffeine"
replace_command_placeholder '@BRIGHTNESS_COMMAND@' "$bin_dir/brightnessctl"
replace_command_placeholder '@REBOOT_COMMAND@' "$bin_dir/hyprshutdown -t 'Restarting...' --post-cmd '$bin_dir/systemctl reboot'"
replace_command_placeholder '@LOCK_COMMAND@' "$bin_dir/loginctl lock-session"
replace_command_placeholder '@SLEEP_COMMAND@' "$bin_dir/systemctl suspend"
replace_command_placeholder '@RFKILL_COMMAND@' "$bin_dir/rfkill"
replace_command_placeholder '@LOGOUT_COMMAND@' "$bin_dir/hyprshutdown"
replace_command_placeholder '@NOTIFY_SEND_COMMAND@' "$bin_dir/notify-send"

if grep -R -n --include='*.qml' '@[A-Z_]*@' "$output_dir" >&2; then
	printf 'hypr-shell-generate-quickshell: generated QML still contains placeholders\n' >&2
	exit 70
fi

printf 'hypr-shell-generate-quickshell: generated Quickshell config at %s\n' "$output_dir" >&2
