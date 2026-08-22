# shellcheck shell=bash

# Beginner orientation:
#
# This script provides one screenshot command with three modes:
# - area: drag to select an area
# - full: capture the whole current screen
# - window: capture the active Hyprland window
#
# Flow: grim's raw capture is copied to the clipboard immediately, before
# satty ever opens. satty is then just an optional annotate/save step -- it
# reads the same capture from stdin. Pressing Enter in satty re-copies the
# annotated version (replacing the raw one on the clipboard) and saves it to
# the screenshots folder; pressing Escape simply closes satty and leaves the
# raw capture already sitting on the clipboard untouched. Either way nothing
# is ever silently lost the way it was when the clipboard copy only happened
# on explicit confirm inside satty.
#
# Tools involved:
# - grim captures pixels on Wayland.
# - slurp lets you select an area with the mouse.
# - hyprctl asks Hyprland for window geometry.
# - jq extracts values from Hyprland's JSON.
# - satty opens the screenshot editor/annotator (optional, for annotating/saving).
# - wl-copy copies the raw capture to the Wayland clipboard immediately, and
#   also copies satty's annotated output if the user confirms.
# - notify-send shows a short completion message after Satty closes.
# - xdg-open opens the screenshots folder when the notification action is used.
#
# The colors in area_geometry are the selection overlay colors. They were tuned
# to match the lavender/accent direction of the ricing.

mode="${1:-area}"
screenshot_dir="${XDG_PICTURES_DIR:-"$HOME/Pictures"}/Screenshots"
# Human-readable stamp, second precision: date hyphenated, time dotted, no
# spaces so the name never needs quoting in a terminal. Strftime-expanded by
# satty, hence the bare % where the record script calls date itself.
output_pattern="$screenshot_dir/screenshot-%Y-%m-%d-%H.%M.%S.png"

mkdir -p "$screenshot_dir"

notify_location() {
	local title="$1"
	local body="$2"
	local location="$3"

	(
		action="$(notify-send \
			--app-name "Hypr Shell" \
			--icon folder-pictures \
			--action=open="Open Folder" \
			"$title" \
			"$body" || true)"

		if [[ "$action" == "open" ]]; then
			xdg-open "$location" >/dev/null 2>&1 &
		fi
	) &
}

# Shared satty options. These control editor behavior after a screenshot is
# taken. For example, --initial-tool arrow means satty opens with the arrow tool
# selected, and --save-after-copy saves a file even when copying to clipboard.
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

# Interactive area selection. slurp returns a geometry string like:
#   10,20 800x600
# grim can use that string to capture exactly that rectangle.
area_geometry() {
	slurp \
		-d \
		-b "#11111bcc" \
		-c "#b4befeff" \
		-s "#b4befe44" \
		-w 3
}

# Active-window capture. Hyprland knows the active window position and size; jq
# turns that JSON into the same geometry format grim expects.
window_geometry() {
	hyprctl activewindow -j |
		jq -er '
      .at as $at
      | .size as $size
      | "\($at[0]),\($at[1]) \($size[0])x\($size[1])"
    '
}

# Capture a region, copy the raw capture to the clipboard immediately, and
# pipe the same image into satty for optional annotation/saving. Empty
# geometry means the user cancelled selection, so exit quietly.
#
# grim defaults to png here (no -t ppm): wl-copy has to advertise a
# paste-friendly image type, and a single png capture can feed both the
# clipboard and satty from the same tee, at the cost of a slightly slower
# encode than ppm.
capture_region() {
	local geometry="$1"

	[[ -n "$geometry" ]] || exit 0
	grim -g "$geometry" - | tee >(wl-copy --type image/png) | satty "${satty_args[@]}"
	notify_location "Screenshot captured" "On the clipboard now; annotated saves go to $screenshot_dir" "$screenshot_dir"
}

case "$mode" in
area)
	capture_region "$(area_geometry || true)"
	;;
full)
	grim - | tee >(wl-copy --type image/png) | satty "${satty_args[@]}"
	notify_location "Screenshot captured" "On the clipboard now; annotated saves go to $screenshot_dir" "$screenshot_dir"
	;;
window)
	capture_region "$(window_geometry || true)"
	;;
*)
	printf 'Usage: %s [area|full|window]\n' "$0" >&2
	exit 64
	;;
esac
