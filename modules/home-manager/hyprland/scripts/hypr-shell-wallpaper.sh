wallpapers_dir="${WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-shell"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-shell"
state_file="$state_dir/wallpaper"
lock_link="$cache_dir/lock-wallpaper"

mkdir -p "$state_dir" "$cache_dir"

list_wallpapers() {
	if [ -d "$wallpapers_dir" ]; then
		find "$wallpapers_dir" -type f \( \
			-iname '*.jpg' -o \
			-iname '*.jpeg' -o \
			-iname '*.png' -o \
			-iname '*.webp' \
			\) | sort
	fi
}

choose_wallpaper() {
	mode="${1:-restore}"

	case "$mode" in
	set)
		candidate="${2:-}"
		if [ -n "$candidate" ] && [ -f "$candidate" ]; then
			printf '%s\n' "$candidate"
		fi
		;;
	random | next)
		list_wallpapers | shuf -n 1
		;;
	restore | *)
		if [ -r "$state_file" ]; then
			candidate="$(cat "$state_file")"
			if [ -f "$candidate" ]; then
				printf '%s\n' "$candidate"
				return
			fi
		fi
		list_wallpapers | head -n 1
		;;
	esac
}

wallpaper="$(choose_wallpaper "${1:-restore}" "${2:-}")"

if [ -z "$wallpaper" ]; then
	printf 'No wallpaper found in %s\n' "$wallpapers_dir" >&2
	exit 1
fi

ln -sfn "$wallpaper" "$lock_link"
printf '%s\n' "$wallpaper" >"$state_file"

if command -v swww >/dev/null 2>&1; then
	swww img "$wallpaper" \
		--transition-type grow \
		--transition-pos 0.85,0.15 \
		--transition-duration 0.6
fi

printf '%s\n' "$wallpaper"
