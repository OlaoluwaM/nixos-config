#!/usr/bin/env bash
set -euo pipefail

mode="${1:-area}"
screenshot_dir="${XDG_PICTURES_DIR:-"$HOME/Pictures"}/Screenshots"
output_pattern="$screenshot_dir/Screenshot-%Y%m%d-%H%M%S.png"

mkdir -p "$screenshot_dir"

satty_args=(
	--filename -
	--fullscreen current-screen
	--floating-hack
	--no-window-decoration
	--initial-tool arrow
	--copy-command wl-copy
	--output-filename "$output_pattern"
	--save-after-copy
	--actions-on-enter save-to-clipboard
	--actions-on-escape exit
	--early-exit
	--corner-roundness 12
)

area_geometry() {
	slurp \
		-d \
		-b "#11111bcc" \
		-c "#cba6f7ff" \
		-s "#cba6f744" \
		-w 3
}

window_geometry() {
	hyprctl activewindow -j |
		jq -er '
      .at as $at
      | .size as $size
      | "\($at[0]),\($at[1]) \($size[0])x\($size[1])"
    '
}

capture_region() {
	local geometry="$1"

	[[ -n "$geometry" ]] || exit 0
	grim -g "$geometry" -t ppm - | satty "${satty_args[@]}"
}

case "$mode" in
area)
	capture_region "$(area_geometry || true)"
	;;
full)
	grim -t ppm - | satty "${satty_args[@]}"
	;;
window)
	capture_region "$(window_geometry || true)"
	;;
*)
	printf 'Usage: %s [area|full|window]\n' "$0" >&2
	exit 64
	;;
esac
