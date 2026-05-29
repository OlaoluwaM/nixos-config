#!/usr/bin/env bash
set -euo pipefail

# Starts a minimal Hyprland session from a real TTY, shows a wallpaper, and
# loads the generated Quickshell config. Nothing else is started on purpose.

usage() {
	cat >&2 <<'EOF'
Usage:
  ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh [--repo PATH] [--monitor RULE] [--wallpaper PATH]

Examples:
  ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh
  ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh --repo ~/Desktop/labs/nixos-config
  ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh --monitor ',preferred,auto,1'
  ./modules/home-manager/hyprland/scripts/hypr-shell-tty-test.sh --wallpaper /path/to/image.jpg

Run from a real TTY on a non-NixOS test host, not from inside another graphical desktop.

Inside the test Hyprland session:
  Super+Escape       Exit the test session
  Super+Shift+Q      Exit the test session
EOF
}

repo_root="${HYPR_SHELL_REPO:-}"
monitor_rule="${HYPR_SHELL_MONITOR_RULE:-,preferred,auto,1}"
hyprland_bin="${HYPR_SHELL_HYPRLAND_BIN:-}"
quickshell_bin="${HYPR_SHELL_QUICKSHELL_BIN:-}"
swaybg_bin="${HYPR_SHELL_SWAYBG_BIN:-}"
default_wallpaper="/home/olaolu/Pictures/wallpapers/skeleton-prophet.jpg"
wallpaper_path="${HYPR_SHELL_TTY_WALLPAPER:-$default_wallpaper}"

while [ "$#" -gt 0 ]; do
	case "$1" in
	--repo)
		if [ "$#" -lt 2 ]; then
			printf 'hypr-shell-tty-test: --repo needs a path\n' >&2
			exit 64
		fi
		repo_root="$2"
		shift 2
		;;
	--monitor)
		if [ "$#" -lt 2 ]; then
			printf 'hypr-shell-tty-test: --monitor needs a Hyprland monitor rule\n' >&2
			exit 64
		fi
		monitor_rule="$2"
		shift 2
		;;
	--wallpaper)
		if [ "$#" -lt 2 ]; then
			printf 'hypr-shell-tty-test: --wallpaper needs an image path\n' >&2
			exit 64
		fi
		wallpaper_path="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'hypr-shell-tty-test: unknown argument: %s\n' "$1" >&2
		usage
		exit 64
		;;
	esac
done

if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
	printf 'hypr-shell-tty-test: run this from a real TTY, not inside a graphical desktop\n' >&2
	exit 69
fi

if [ -z "$hyprland_bin" ]; then
	hyprland_bin="$(command -v Hyprland 2>/dev/null || true)"
fi

if [ -z "$hyprland_bin" ] || [ ! -x "$hyprland_bin" ]; then
	printf 'hypr-shell-tty-test: Hyprland is not available on PATH\n' >&2
	exit 69
fi

if [ -z "$quickshell_bin" ]; then
	quickshell_bin="$(command -v quickshell 2>/dev/null || true)"
fi

if [ -z "$quickshell_bin" ] || [ ! -x "$quickshell_bin" ]; then
	printf 'hypr-shell-tty-test: quickshell is not available on PATH\n' >&2
	exit 69
fi

if ! wallpaper_path="$(realpath "$wallpaper_path" 2>/dev/null)"; then
	printf 'hypr-shell-tty-test: wallpaper path does not exist: %s\n' "$wallpaper_path" >&2
	exit 66
fi

if [ -z "$repo_root" ]; then
	if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
		repo_root="$git_root"
	else
		printf 'hypr-shell-tty-test: could not find repo root\n' >&2
		printf 'Run from the repo, set HYPR_SHELL_REPO, or pass --repo PATH.\n' >&2
		exit 64
	fi
fi

repo_root="$(realpath "$repo_root")"
generator_script="$repo_root/modules/home-manager/hyprland/scripts/hypr-shell-generate-quickshell.sh"

if [ ! -f "$generator_script" ]; then
	printf 'hypr-shell-tty-test: expected Quickshell generator not found:\n  %s\n' "$generator_script" >&2
	exit 66
fi

runtime_root="${XDG_RUNTIME_DIR:-/tmp}/hypr-shell-tty-test"
if ! mkdir -p "$runtime_root" 2>/dev/null || [ ! -w "$runtime_root" ]; then
	runtime_root="/tmp/hypr-shell-tty-test-${UID:-$(id -u)}"
	mkdir -p "$runtime_root"
fi

config_dir="$runtime_root/quickshell"
session_dir="$runtime_root/hyprland"
hypr_config="$session_dir/hyprland.conf"
start_wallpaper="$session_dir/start-wallpaper.sh"

mkdir -p "$session_dir"

bash "$generator_script" --repo "$repo_root" --output "$config_dir"

tty_bin_dir="$runtime_root/bin"
printf -v quickshell_cmd '%q' "$quickshell_bin"
printf -v config_dir_arg '%q' "$config_dir"
printf -v wallpaper_arg '%q' "$wallpaper_path"
printf -v qs_log_arg '%q' "$runtime_root/quickshell.log"

cat >"$start_wallpaper" <<EOF
#!/usr/bin/env bash
set -euo pipefail

wallpaper=${wallpaper_arg}
swaybg_bin=${swaybg_bin@Q}

if [ -n "\$swaybg_bin" ] && [ -x "\$swaybg_bin" ]; then
	exec "\$swaybg_bin" --image "\$wallpaper" --mode fill
fi

if command -v swaybg >/dev/null 2>&1; then
	exec swaybg --image "\$wallpaper" --mode fill
fi

printf 'hypr-shell-tty-test: swaybg is not available on PATH\n' >&2
exit 69
EOF
chmod +x "$start_wallpaper"

printf -v start_wallpaper_cmd '%q' "$start_wallpaper"

# Mirror the window decoration of the real session so rounding/border tweaks
# are visible here. Colours are read from the generated Theme.qml (single
# source) rather than hardcoded; the geometry values mirror the general/
# decoration blocks in quickshell.nix and must be kept in step with them.
theme_qml="$config_dir/Theme.qml"
read_theme_color() {
	grep -oE "property color $1:[[:space:]]*\"#[0-9a-fA-F]+\"" "$theme_qml" 2>/dev/null |
		grep -oE '[0-9a-fA-F]{6,8}' | head -1
}
border_active="$(read_theme_color primary)"
border_inactive="$(read_theme_color outline)"
: "${border_active:=b4befe}"
: "${border_inactive:=45475a}"

cat >"$hypr_config" <<EOF
# Generated by hypr-shell-tty-test.
# Minimal session: Hyprland + wallpaper + Quickshell only.

monitor = ${monitor_rule}

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland
env = HYPR_SHELL_TTY_TEST,1

exec-once = ${start_wallpaper_cmd}
exec-once = ${quickshell_cmd} --path ${config_dir_arg} >${qs_log_arg} 2>&1

input {
  kb_layout = us
}

general {
  gaps_in = 4
  gaps_out = 8
  border_size = 2
  col.active_border = rgb(${border_active})
  col.inactive_border = rgb(${border_inactive})
}

decoration {
  rounding = 14
	# Commenting this out because it is not a valid option for the version of Hyprland used in by TTY test on our current host.
  # rounding_power = 3.5
}

misc {
  disable_hyprland_logo = true
  disable_splash_rendering = true
}

bind = SUPER, Escape, exit
bind = SUPER SHIFT, Q, exit
bind = SUPER, Return, exec, foot || kitty || alacritty || xterm
bind = SUPER, D, exec, wofi --show drun || fuzzel || bemenu-run

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9

bindel = , XF86AudioRaiseVolume, exec, ${tty_bin_dir}/hypr-shell-popup audio-up
bindel = , XF86AudioLowerVolume, exec, ${tty_bin_dir}/hypr-shell-popup audio-down
bindl = , XF86AudioMute, exec, ${tty_bin_dir}/hypr-shell-popup audio-mute
bindel = , XF86MonBrightnessUp, exec, brightnessctl set 5%+ && ${tty_bin_dir}/hypr-shell-popup osd-brightness
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%- && ${tty_bin_dir}/hypr-shell-popup osd-brightness
bindel = , XF86KbdBrightnessUp, exec, brightnessctl -d '*::kbd_backlight' set 5%+ && ${tty_bin_dir}/hypr-shell-popup osd-keyboard
bindel = , XF86KbdBrightnessDown, exec, brightnessctl -d '*::kbd_backlight' set 5%- && ${tty_bin_dir}/hypr-shell-popup osd-keyboard
EOF

printf 'hypr-shell-tty-test: Hyprland config: %s\n' "$hypr_config" >&2
printf 'hypr-shell-tty-test: Quickshell config: %s\n' "$config_dir" >&2
printf 'hypr-shell-tty-test: wallpaper: %s\n' "$wallpaper_path" >&2
printf 'hypr-shell-tty-test: quickshell log: %s\n' "$runtime_root/quickshell.log" >&2
printf 'hypr-shell-tty-test: keybinds:\n' >&2
printf '  Super+Escape / Super+Shift+Q  Exit\n' >&2
printf '  Super+Return                  Terminal\n' >&2
printf '  Super+D                       App launcher\n' >&2
printf '  Super+1-9                     Switch workspace\n' >&2
printf '  Super+Shift+1-9               Move window to workspace\n' >&2

# Always use dbus-run-session to get an isolated D-Bus bus. Without this,
# the systemd user bus (/run/user/UID/bus) is shared with other sessions
# (e.g. GNOME), and gnome-shell already owns org.kde.StatusNotifierWatcher,
# preventing Quickshell from receiving tray icon registrations.
exec dbus-run-session "$hyprland_bin" --config "$hypr_config"
